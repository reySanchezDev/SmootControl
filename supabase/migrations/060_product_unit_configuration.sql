-- Moves product unit behavior toward an LS Central-style configuration.
-- Inventory remains stored in base units, while count/display and recipe
-- default units are product-specific metadata.

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS recipe_default_unit_id uuid
    REFERENCES public.measurement_units(id),
  ADD COLUMN IF NOT EXISTS inventory_display_unit_id uuid
    REFERENCES public.measurement_units(id);

UPDATE public.products
   SET recipe_default_unit_id = COALESCE(recipe_default_unit_id, inventory_unit_id),
       inventory_display_unit_id = COALESCE(
         inventory_display_unit_id,
         purchase_unit_id,
         inventory_unit_id
       )
 WHERE tracks_inventory = true;

ALTER TABLE public.inventory_adjustment_lines
  ALTER COLUMN stock_before TYPE numeric(18, 6)
  USING stock_before::numeric,
  ALTER COLUMN counted_quantity TYPE numeric(18, 6)
  USING counted_quantity::numeric,
  ALTER COLUMN quantity_delta TYPE numeric(18, 6)
  USING quantity_delta::numeric;

ALTER TABLE public.inventory_adjustment_lines
  ADD COLUMN IF NOT EXISTS entered_count_quantity numeric(18, 6),
  ADD COLUMN IF NOT EXISTS entered_count_unit_id uuid
    REFERENCES public.measurement_units(id);

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
  expected_quantity numeric(18, 6);
  counted_quantity numeric(18, 6);
  entered_quantity numeric(18, 6);
  entered_unit_id uuid;
  current_quantity numeric(18, 6);
  quantity_delta numeric(18, 6);
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
    restaurant_id, next_number, updated_at
  )
  VALUES (p_restaurant_id, 1, now())
  ON CONFLICT (restaurant_id) DO NOTHING;

  UPDATE public.inventory_adjustment_number_settings
     SET next_number = next_number + 1,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
  RETURNING next_number - 1 INTO document_number;

  INSERT INTO public.inventory_adjustment_documents (
    restaurant_id, document_number, note, created_by_user_id, created_at
  )
  VALUES (
    p_restaurant_id, document_number, NULLIF(btrim(COALESCE(p_note, '')), ''),
    auth.uid(), now()
  )
  RETURNING id INTO document_id;

  FOR item_payload IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    target_product_id := (item_payload ->> 'product_id')::uuid;
    expected_quantity := (item_payload ->> 'expected_quantity')::numeric;
    counted_quantity := (item_payload ->> 'counted_quantity')::numeric;
    entered_quantity := NULLIF(
      item_payload ->> 'entered_count_quantity',
      ''
    )::numeric;
    entered_unit_id := NULLIF(item_payload ->> 'entered_count_unit_id', '')::uuid;

    IF counted_quantity IS NULL OR counted_quantity < 0 THEN
      RAISE EXCEPTION 'Conteo de producto invalido'
        USING ERRCODE = '23514';
    END IF;

    IF expected_quantity IS NULL OR expected_quantity < 0 THEN
      RAISE EXCEPTION 'Stock esperado invalido'
        USING ERRCODE = '23514';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.products product
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
      restaurant_id, product_id, quantity_on_hand, created_at, updated_at
    )
    VALUES (p_restaurant_id, target_product_id, 0, now(), now())
    ON CONFLICT (restaurant_id, product_id) DO NOTHING;

    SELECT quantity_on_hand INTO current_quantity
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
      document_id, restaurant_id, product_id, stock_before,
      counted_quantity, quantity_delta, entered_count_quantity,
      entered_count_unit_id, created_at
    )
    VALUES (
      document_id, p_restaurant_id, target_product_id, current_quantity,
      counted_quantity, quantity_delta, entered_quantity, entered_unit_id, now()
    );

    INSERT INTO public.inventory_movements (
      id, restaurant_id, product_id, movement_type, quantity_delta, unit_cost,
      reference_type, reference_id, user_id, notes, created_at
    )
    VALUES (
      movement_id, p_restaurant_id, target_product_id, 'adjustment',
      quantity_delta, 0, 'inventory_adjustment', document_id::text,
      auth.uid()::text, NULLIF(btrim(COALESCE(p_note, '')), ''), now()
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

