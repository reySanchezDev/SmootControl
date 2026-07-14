-- Remote administrative inventory count adjustments.
-- Admin records a single adjustment document; POS later pulls stock through sync.

ALTER TABLE public.inventory_movements
  DROP CONSTRAINT IF EXISTS inventory_movements_movement_type_check;

ALTER TABLE public.inventory_movements
  ADD CONSTRAINT inventory_movements_movement_type_check
  CHECK (movement_type IN ('purchase', 'sale', 'sale_void', 'adjustment'));

CREATE TABLE IF NOT EXISTS public.inventory_adjustment_number_settings (
  restaurant_id uuid PRIMARY KEY REFERENCES public.restaurants(id)
    ON DELETE CASCADE,
  next_number bigint NOT NULL DEFAULT 1 CHECK (next_number > 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.inventory_adjustment_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id)
    ON DELETE CASCADE,
  document_number bigint NOT NULL,
  note text,
  created_by_user_id uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, document_number)
);

CREATE TABLE IF NOT EXISTS public.inventory_adjustment_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.inventory_adjustment_documents(id)
    ON DELETE CASCADE,
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id)
    ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  stock_before integer NOT NULL CHECK (stock_before >= 0),
  counted_quantity integer NOT NULL CHECK (counted_quantity >= 0),
  quantity_delta integer NOT NULL CHECK (quantity_delta <> 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS inventory_adjustment_documents_restaurant_created_idx
  ON public.inventory_adjustment_documents (restaurant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS inventory_adjustment_lines_document_idx
  ON public.inventory_adjustment_lines (document_id);

ALTER TABLE public.inventory_adjustment_number_settings
  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_adjustment_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_adjustment_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inventory_adjustment_numbers_same_restaurant
  ON public.inventory_adjustment_number_settings;
CREATE POLICY inventory_adjustment_numbers_same_restaurant
  ON public.inventory_adjustment_number_settings
  FOR ALL
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS inventory_adjustment_documents_same_restaurant
  ON public.inventory_adjustment_documents;
CREATE POLICY inventory_adjustment_documents_same_restaurant
  ON public.inventory_adjustment_documents
  FOR ALL
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS inventory_adjustment_lines_same_restaurant
  ON public.inventory_adjustment_lines;
CREATE POLICY inventory_adjustment_lines_same_restaurant
  ON public.inventory_adjustment_lines
  FOR ALL
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

CREATE OR REPLACE FUNCTION public.app_register_inventory_adjustment_batch(
  p_restaurant_id uuid,
  p_items jsonb,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item_payload jsonb;
  item_count integer := 0;
  target_product_id uuid;
  expected_quantity integer;
  counted_quantity integer;
  current_quantity integer;
  quantity_delta integer;
  movement_id text;
  document_id uuid;
  document_number bigint;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'inventario.gestionar'
  );

  IF jsonb_typeof(COALESCE(p_items, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'Lista de ajuste de inventario invalida'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.inventory_adjustment_number_settings (
    restaurant_id,
    next_number,
    updated_at
  )
  VALUES (p_restaurant_id, 1, now())
  ON CONFLICT (restaurant_id) DO NOTHING;

  UPDATE public.inventory_adjustment_number_settings
     SET next_number = next_number + 1,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
  RETURNING next_number - 1 INTO document_number;

  INSERT INTO public.inventory_adjustment_documents (
    restaurant_id,
    document_number,
    note,
    created_by_user_id,
    created_at
  )
  VALUES (
    p_restaurant_id,
    document_number,
    NULLIF(btrim(COALESCE(p_note, '')), ''),
    auth.uid(),
    now()
  )
  RETURNING id INTO document_id;

  FOR item_payload IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    target_product_id := (item_payload ->> 'product_id')::uuid;
    expected_quantity := (item_payload ->> 'expected_quantity')::integer;
    counted_quantity := (item_payload ->> 'counted_quantity')::integer;

    IF counted_quantity IS NULL OR counted_quantity < 0 THEN
      RAISE EXCEPTION 'Conteo de producto invalido'
        USING ERRCODE = '23514';
    END IF;

    IF expected_quantity IS NULL OR expected_quantity < 0 THEN
      RAISE EXCEPTION 'Stock esperado invalido'
        USING ERRCODE = '23514';
    END IF;

    IF NOT EXISTS (
      SELECT 1
        FROM public.products product
       WHERE product.id = target_product_id
         AND product.restaurant_id = p_restaurant_id
         AND product.is_active = true
         AND product.tracks_inventory = true
    ) THEN
      RAISE EXCEPTION 'Producto remoto no activo o no controla inventario: %',
        target_product_id
        USING ERRCODE = '23503';
    END IF;

    INSERT INTO public.inventory_stock (
      restaurant_id,
      product_id,
      quantity_on_hand,
      created_at,
      updated_at
    )
    VALUES (p_restaurant_id, target_product_id, 0, now(), now())
    ON CONFLICT (restaurant_id, product_id) DO NOTHING;

    SELECT quantity_on_hand
      INTO current_quantity
      FROM public.inventory_stock
     WHERE restaurant_id = p_restaurant_id
       AND product_id = target_product_id
     FOR UPDATE;

    IF current_quantity <> expected_quantity THEN
      RAISE EXCEPTION 'El stock remoto cambio. Refresca el inventario.'
        USING ERRCODE = '40001';
    END IF;

    quantity_delta := counted_quantity - current_quantity;
    IF quantity_delta = 0 THEN
      CONTINUE;
    END IF;

    movement_id := COALESCE(
      NULLIF(item_payload ->> 'movement_id', ''),
      gen_random_uuid()::text
    );

    INSERT INTO public.inventory_adjustment_lines (
      document_id,
      restaurant_id,
      product_id,
      stock_before,
      counted_quantity,
      quantity_delta,
      created_at
    )
    VALUES (
      document_id,
      p_restaurant_id,
      target_product_id,
      current_quantity,
      counted_quantity,
      quantity_delta,
      now()
    );

    INSERT INTO public.inventory_movements (
      id,
      restaurant_id,
      product_id,
      movement_type,
      quantity_delta,
      unit_cost,
      reference_type,
      reference_id,
      user_id,
      notes,
      created_at
    )
    VALUES (
      movement_id,
      p_restaurant_id,
      target_product_id,
      'adjustment',
      quantity_delta,
      0,
      'inventory_adjustment',
      document_id::text,
      auth.uid()::text,
      NULLIF(btrim(COALESCE(p_note, '')), ''),
      now()
    );

    UPDATE public.inventory_stock
       SET quantity_on_hand = counted_quantity,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id
       AND product_id = target_product_id;

    item_count := item_count + 1;
  END LOOP;

  IF item_count = 0 THEN
    RAISE EXCEPTION 'No hay cambios de inventario para registrar'
      USING ERRCODE = '23514';
  END IF;

  RETURN jsonb_build_object(
    'document_id', document_id,
    'document_number', document_number,
    'item_count', item_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.app_register_inventory_adjustment_batch(
  uuid,
  jsonb,
  text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_register_inventory_adjustment_batch(
  uuid,
  jsonb,
  text
) TO authenticated;
