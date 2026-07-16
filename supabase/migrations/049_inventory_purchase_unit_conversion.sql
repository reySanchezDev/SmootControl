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
  quantity numeric;
  target_quantity integer;
  unit_cost numeric;
  base_unit_cost numeric;
  movement_id text;
  purchase_unit_id uuid;
  product_row public.products%ROWTYPE;
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
    quantity := (item_payload ->> 'quantity')::numeric;
    unit_cost := (item_payload ->> 'unit_cost')::numeric;
    purchase_unit_id := NULLIF(item_payload ->> 'purchase_unit_id', '')::uuid;

    IF quantity IS NULL OR quantity <= 0 THEN
      RAISE EXCEPTION 'Cantidad de producto invalida'
        USING ERRCODE = '23514';
    END IF;

    IF unit_cost IS NULL OR unit_cost < 0 THEN
      RAISE EXCEPTION 'Costo unitario de producto invalido'
        USING ERRCODE = '23514';
    END IF;

    SELECT *
      INTO product_row
      FROM public.products product
     WHERE product.id = product_id
       AND product.restaurant_id = p_restaurant_id
       AND product.is_active = true
       AND product.tracks_inventory = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Producto remoto no activo o no controla inventario: %',
        product_id
        USING ERRCODE = '23503';
    END IF;

    target_quantity := quantity::integer;
    base_unit_cost := unit_cost;

    IF purchase_unit_id IS NOT NULL THEN
      IF product_row.purchase_unit_id IS NULL
         OR product_row.inventory_unit_id IS NULL
         OR product_row.purchase_to_inventory_factor IS NULL
         OR product_row.purchase_to_inventory_factor <= 0 THEN
        RAISE EXCEPTION 'Producto sin conversion de unidad de compra: %',
          product_id
          USING ERRCODE = '23514';
      END IF;

      IF purchase_unit_id <> product_row.purchase_unit_id THEN
        RAISE EXCEPTION 'Unidad de compra no coincide para producto: %',
          product_id
          USING ERRCODE = '23514';
      END IF;

      target_quantity := ROUND(
        quantity * product_row.purchase_to_inventory_factor
      )::integer;
      base_unit_cost := unit_cost / product_row.purchase_to_inventory_factor;
    END IF;

    IF target_quantity <= 0 THEN
      RAISE EXCEPTION 'Cantidad base de producto invalida'
        USING ERRCODE = '23514';
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
      target_quantity,
      'admin_batch_purchase',
      movement_id,
      auth.uid()::text,
      NULL,
      now(),
      base_unit_cost
    );

    UPDATE public.products
       SET cost = base_unit_cost,
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
