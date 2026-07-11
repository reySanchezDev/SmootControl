-- Remote-only administrative inventory purchases.
-- Admin screens must write directly to Supabase; POS local inventory is updated
-- later only through catalog/device synchronization.

ALTER TABLE public.inventory_movements
  ADD COLUMN IF NOT EXISTS unit_cost numeric(15, 4) NOT NULL DEFAULT 0
    CHECK (unit_cost >= 0);

DROP FUNCTION IF EXISTS public.apply_inventory_movement(
  text,
  uuid,
  uuid,
  text,
  integer,
  text,
  text,
  text,
  text,
  timestamptz
);

CREATE OR REPLACE FUNCTION public.apply_inventory_movement(
  p_id text,
  p_restaurant_id uuid,
  p_product_id uuid,
  p_movement_type text,
  p_quantity_delta integer,
  p_reference_type text DEFAULT NULL,
  p_reference_id text DEFAULT NULL,
  p_user_id text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_created_at timestamptz DEFAULT NULL,
  p_unit_cost numeric DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_quantity integer;
  next_quantity integer;
BEGIN
  IF NOT public.is_same_restaurant(p_restaurant_id) THEN
    RAISE EXCEPTION 'No autorizado para inventario del restaurante %',
      p_restaurant_id
      USING ERRCODE = '42501';
  END IF;

  IF p_id IS NULL OR btrim(p_id) = '' THEN
    RAISE EXCEPTION 'Movimiento de inventario sin id'
      USING ERRCODE = '23502';
  END IF;

  IF p_movement_type NOT IN ('purchase', 'sale', 'sale_void') THEN
    RAISE EXCEPTION 'Tipo de movimiento de inventario invalido: %',
      p_movement_type
      USING ERRCODE = '23514';
  END IF;

  IF p_quantity_delta IS NULL OR p_quantity_delta = 0 THEN
    RAISE EXCEPTION 'Cantidad de inventario invalida'
      USING ERRCODE = '23514';
  END IF;

  IF COALESCE(p_unit_cost, 0) < 0 THEN
    RAISE EXCEPTION 'Costo unitario de inventario invalido'
      USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM public.products product
     WHERE product.id = p_product_id
       AND product.restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Producto no pertenece al restaurante'
      USING ERRCODE = '23503';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.inventory_movements
    WHERE id = p_id
  ) THEN
    RETURN;
  END IF;

  INSERT INTO public.inventory_stock (
    restaurant_id,
    product_id,
    quantity_on_hand,
    created_at,
    updated_at
  )
  VALUES (
    p_restaurant_id,
    p_product_id,
    0,
    now(),
    now()
  )
  ON CONFLICT (restaurant_id, product_id) DO NOTHING;

  SELECT quantity_on_hand
    INTO current_quantity
    FROM public.inventory_stock
   WHERE restaurant_id = p_restaurant_id
     AND product_id = p_product_id
   FOR UPDATE;

  next_quantity := current_quantity + p_quantity_delta;
  IF next_quantity < 0 THEN
    RAISE EXCEPTION 'Stock insuficiente para producto %', p_product_id
      USING ERRCODE = '23514';
  END IF;

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
    p_id,
    p_restaurant_id,
    p_product_id,
    p_movement_type,
    p_quantity_delta,
    COALESCE(p_unit_cost, 0),
    p_reference_type,
    p_reference_id,
    p_user_id,
    p_notes,
    COALESCE(p_created_at, now())
  );

  UPDATE public.inventory_stock
     SET quantity_on_hand = next_quantity,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
     AND product_id = p_product_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_register_inventory_purchase_batch(
  p_restaurant_id uuid,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item_payload jsonb;
  item_count integer := 0;
  product_id uuid;
  quantity integer;
  unit_cost numeric;
  movement_id text;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'inventario.gestionar'
  );

  IF jsonb_typeof(COALESCE(p_items, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'Lista de productos invalida'
      USING ERRCODE = '22023';
  END IF;

  FOR item_payload IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    product_id := (item_payload ->> 'product_id')::uuid;
    quantity := (item_payload ->> 'quantity')::integer;
    unit_cost := (item_payload ->> 'unit_cost')::numeric;

    IF quantity IS NULL OR quantity <= 0 THEN
      RAISE EXCEPTION 'Cantidad de producto invalida'
        USING ERRCODE = '23514';
    END IF;

    IF unit_cost IS NULL OR unit_cost < 0 THEN
      RAISE EXCEPTION 'Costo unitario de producto invalido'
        USING ERRCODE = '23514';
    END IF;

    IF NOT EXISTS (
      SELECT 1
        FROM public.products product
       WHERE product.id = product_id
         AND product.restaurant_id = p_restaurant_id
         AND product.is_active = true
         AND product.tracks_inventory = true
    ) THEN
      RAISE EXCEPTION 'Producto remoto no activo o no controla inventario: %',
        product_id
        USING ERRCODE = '23503';
    END IF;

    movement_id := COALESCE(
      NULLIF(item_payload ->> 'movement_id', ''),
      gen_random_uuid()::text
    );

    PERFORM public.apply_inventory_movement(
      movement_id,
      p_restaurant_id,
      product_id,
      'purchase',
      quantity,
      'admin_batch_purchase',
      movement_id,
      auth.uid()::text,
      NULL,
      now(),
      unit_cost
    );

    UPDATE public.products
       SET cost = unit_cost,
           updated_at = now()
     WHERE id = product_id
       AND restaurant_id = p_restaurant_id;

    item_count := item_count + 1;
  END LOOP;

  IF item_count = 0 THEN
    RAISE EXCEPTION 'No hay productos para registrar'
      USING ERRCODE = '23514';
  END IF;

  RETURN jsonb_build_object('item_count', item_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_register_packaging_purchase_batch(
  p_restaurant_id uuid,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item_payload jsonb;
  item_count integer := 0;
  packaging_item_id uuid;
  quantity integer;
  unit_cost numeric;
  movement_id text;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'inventario.gestionar'
  );

  IF jsonb_typeof(COALESCE(p_items, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'Lista de empaques invalida'
      USING ERRCODE = '22023';
  END IF;

  FOR item_payload IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    packaging_item_id := (item_payload ->> 'packaging_item_id')::uuid;
    quantity := (item_payload ->> 'quantity')::integer;
    unit_cost := (item_payload ->> 'unit_cost')::numeric;

    IF quantity IS NULL OR quantity <= 0 THEN
      RAISE EXCEPTION 'Cantidad de empaque invalida'
        USING ERRCODE = '23514';
    END IF;

    IF unit_cost IS NULL OR unit_cost < 0 THEN
      RAISE EXCEPTION 'Costo unitario de empaque invalido'
        USING ERRCODE = '23514';
    END IF;

    IF NOT EXISTS (
      SELECT 1
        FROM public.packaging_items item
       WHERE item.id = packaging_item_id
         AND item.restaurant_id = p_restaurant_id
         AND item.is_active = true
         AND item.tracks_stock = true
    ) THEN
      RAISE EXCEPTION 'Empaque remoto no activo o no controla stock: %',
        packaging_item_id
        USING ERRCODE = '23503';
    END IF;

    movement_id := COALESCE(
      NULLIF(item_payload ->> 'movement_id', ''),
      gen_random_uuid()::text
    );

    PERFORM public.apply_packaging_movement(
      movement_id,
      p_restaurant_id,
      packaging_item_id,
      'packaging_purchase',
      quantity,
      unit_cost,
      'admin_batch_purchase',
      movement_id,
      auth.uid()::text,
      NULL,
      now()
    );

    UPDATE public.packaging_items
       SET cost = unit_cost,
           updated_at = now()
     WHERE id = packaging_item_id
       AND restaurant_id = p_restaurant_id;

    item_count := item_count + 1;
  END LOOP;

  IF item_count = 0 THEN
    RAISE EXCEPTION 'No hay empaques para registrar'
      USING ERRCODE = '23514';
  END IF;

  RETURN jsonb_build_object('item_count', item_count);
END;
$$;

REVOKE ALL ON FUNCTION public.apply_inventory_movement(
  text,
  uuid,
  uuid,
  text,
  integer,
  text,
  text,
  text,
  text,
  timestamptz,
  numeric
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_register_inventory_purchase_batch(uuid, jsonb)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_register_packaging_purchase_batch(uuid, jsonb)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.apply_inventory_movement(
  text,
  uuid,
  uuid,
  text,
  integer,
  text,
  text,
  text,
  text,
  timestamptz,
  numeric
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_register_inventory_purchase_batch(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_register_packaging_purchase_batch(uuid, jsonb)
  TO authenticated;
