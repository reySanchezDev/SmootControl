-- Local-only end-to-end contract test. Every mutation is rolled back.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b096e0cb-2a63-4559-960f-0db22b260b85","restaurant_id":"0f4e9ea0-948e-4d07-b2e0-55a96b3a462f"}',
  true
);

DO $$
DECLARE
  v_restaurant uuid := '0f4e9ea0-948e-4d07-b2e0-55a96b3a462f';
  v_item public.items;
  v_existing public.items;
  v_sale_id uuid := gen_random_uuid();
  v_line_id uuid := gen_random_uuid();
  v_device_id uuid;
  v_device_secret text;
  v_cash_session uuid;
  v_user_id uuid;
  v_payment_method uuid;
  v_packaging_item uuid;
  v_sales_type uuid;
  v_result jsonb;
  v_stock_before numeric;
  v_stock_after numeric;
  v_component_stock_before numeric;
  v_packaging_stock_before numeric;
  v_report_rows integer;
BEGIN
  v_device_id := gen_random_uuid();
  v_device_secret := 'qa-local-device-secret-20261117-0001';
  SELECT id, cashier_user_id INTO v_cash_session, v_user_id
  FROM public.cash_register_sessions
  WHERE restaurant_id = v_restaurant AND status = 'open'
  LIMIT 1;
  SELECT id INTO v_payment_method
  FROM public.payment_methods
  WHERE restaurant_id = v_restaurant AND is_active
  LIMIT 1;
  SELECT id INTO v_packaging_item
  FROM public.items
  WHERE restaurant_id = v_restaurant AND item_class = 'packaging'
    AND tracks_inventory AND can_purchase AND is_active
  LIMIT 1;
  SELECT id INTO v_sales_type
  FROM public.sales_types
  WHERE restaurant_id = v_restaurant AND is_active
  LIMIT 1;
  SELECT * INTO v_existing
  FROM public.items
  WHERE restaurant_id = v_restaurant AND item_class = 'raw_material'
    AND tracks_inventory AND is_active
    AND EXISTS (
      SELECT 1 FROM public.inventory_stock stock
      WHERE stock.restaurant_id = v_restaurant
        AND stock.item_id = public.items.id
        AND stock.quantity_on_hand >= 1
    )
    AND EXISTS (
      SELECT 1 FROM public.measurement_units unit
      WHERE unit.id = public.items.base_unit_id
        AND (unit.restaurant_id IS NULL OR unit.restaurant_id = v_restaurant)
        AND unit.is_active
    )
  LIMIT 1;
  PERFORM public.register_pos_device(
    v_restaurant, v_device_id, v_device_secret, 'QA E2E temporal'
  );
  IF v_cash_session IS NULL OR v_payment_method IS NULL
     OR v_packaging_item IS NULL OR v_sales_type IS NULL
     OR v_existing.id IS NULL THEN
    RAISE EXCEPTION 'Fixture local insuficiente para E2E.';
  END IF;

  SELECT * INTO v_item FROM public.app_upsert_item_v2(
    v_restaurant,
    jsonb_build_object(
      'name', 'QA ITEM E2E ' || substr(gen_random_uuid()::text, 1, 8),
      'item_type', 'inventory', 'base_unit_id', v_existing.base_unit_id,
      'base_unit_cost', 1, 'base_unit_price', 2,
      'can_sell', true, 'can_purchase', true,
      'visible_in_pos', true, 'is_active', true
    )
  );
  IF v_item.code !~ '^ART-[0-9]+$' THEN
    RAISE EXCEPTION 'Codigo comercial no generado por PostgreSQL: %', v_item.code;
  END IF;

  SELECT * INTO v_item FROM public.app_upsert_item_v2(
    v_restaurant,
    jsonb_build_object('id', v_item.id, 'name', 'QA ITEM E2E EDITADO',
      'item_type', 'inventory', 'base_unit_id', v_item.base_unit_id,
      'base_unit_cost', 1, 'base_unit_price', 2,
      'can_sell', true, 'can_purchase', true,
      'visible_in_pos', true, 'uses_recipe', true,
      'is_active', true)
  );
  IF v_item.code !~ '^ART-[0-9]+$' OR v_item.name <> 'QA ITEM E2E EDITADO' THEN
    RAISE EXCEPTION 'Edicion canonica no preservo codigo/nombre.';
  END IF;

  PERFORM public.app_save_item_recipe_v2(
    v_restaurant, v_item.id,
    jsonb_build_array(jsonb_build_object(
      'component_item_id', v_existing.id, 'quantity', 1,
      'unit_id', v_existing.base_unit_id, 'waste_percent', 0,
      'display_order', 0))
  );
  IF NOT EXISTS (
    SELECT 1 FROM public.item_recipe_lines line
    JOIN public.item_recipes recipe ON recipe.id = line.recipe_id
    WHERE recipe.item_id = v_item.id AND line.component_item_id = v_existing.id
  ) THEN
    RAISE EXCEPTION 'La receta canonica no persistio sus componentes.';
  END IF;

  PERFORM public.app_upsert_item_consumption_rule_v2(
    v_restaurant,
    jsonb_build_object('source_item_id', v_item.id,
      'consumed_item_id', v_packaging_item, 'sales_type_id', v_sales_type,
      'scope', 'per_sale_line', 'quantity', 1,
      'unit_id', v_existing.base_unit_id, 'priority', 100, 'is_active', true)
  );
  IF NOT EXISTS (
    SELECT 1 FROM public.item_consumption_rules
    WHERE source_item_id = v_item.id AND consumed_item_id = v_packaging_item
  ) THEN
    RAISE EXCEPTION 'La regla canonica de consumo no persistio.';
  END IF;

  PERFORM public.app_register_inventory_purchase_batch_v2(
    v_restaurant,
    jsonb_build_array(
      jsonb_build_object(
        'movement_id', 'qa-e2e-product-stock-' || substr(v_sale_id::text, 1, 8),
        'item_id', v_item.id, 'quantity', 5, 'unit_cost', 1
      ),
      jsonb_build_object(
        'movement_id', 'qa-e2e-packaging-stock-' || substr(v_sale_id::text, 1, 8),
        'item_id', v_packaging_item, 'quantity', 5, 'unit_cost', 1
      )
    )
  );
  SELECT quantity_on_hand INTO v_stock_before
  FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_item.id;
  SELECT quantity_on_hand INTO v_component_stock_before
  FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_existing.id;
  SELECT quantity_on_hand INTO v_packaging_stock_before
  FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_packaging_item;
  v_result := public.pos_sync_sale_v2(
    v_restaurant, v_device_id, v_device_secret,
    jsonb_build_object(
      'sale', jsonb_build_object('id', v_sale_id, 'local_id', v_sale_id::text,
        'invoice_number', 'QA-E2E-' || substr(v_sale_id::text, 1, 8),
        'cash_register_session_id', v_cash_session, 'user_id', v_user_id,
        'payment_method_id', v_payment_method, 'sales_type_id', v_sales_type,
        'total_amount', 2,
        'total_cost', 1, 'gross_profit', 1, 'status', 'completed',
        'sold_at', now(), 'business_date', current_date),
      'items', jsonb_build_array(jsonb_build_object(
        'id', v_line_id, 'item_id', v_item.id, 'product_code', v_item.code,
        'product_name', v_item.name, 'category_name', 'QA', 'quantity', 1,
        'unit_price', 2, 'unit_cost', 1, 'subtotal', 2, 'gross_profit', 1)),
      'inventory_movements', jsonb_build_array(jsonb_build_object(
        'id', 'qa-e2e-movement-' || substr(v_sale_id::text, 1, 8),
        'item_id', v_item.id, 'movement_type', 'sale', 'quantity_delta', -1,
        'unit_cost', 1, 'created_at', now())),
      'packaging_movements', jsonb_build_array(jsonb_build_object(
        'id', 'qa-e2e-packaging-' || substr(v_sale_id::text, 1, 8),
        'packaging_item_id', v_packaging_item,
        'movement_type', 'packaging_sale', 'quantity_delta', -1,
        'unit_cost', 1, 'reference_type', 'sale',
        'reference_id', v_sale_id::text, 'created_at', now()))
    )
  );
  RAISE NOTICE 'POS result %', v_result;
  RAISE NOTICE 'POS movement count %', (
    SELECT count(*) FROM public.inventory_movements WHERE reference_id = v_sale_id::text
  );
  IF (v_result ->> 'remote_id')::uuid <> v_sale_id THEN
    RAISE EXCEPTION 'POS no devolvio la venta sincronizada.';
  END IF;
  SELECT quantity_on_hand INTO v_stock_after
  FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_item.id;
  IF v_stock_after <> v_stock_before - 1 THEN
    RAISE EXCEPTION 'El POS no desconto stock canonico: % -> %', v_stock_before, v_stock_after;
  END IF;
  SELECT quantity_on_hand INTO v_stock_after
  FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_existing.id;
  IF v_stock_after <> v_component_stock_before - 1 THEN
    RAISE EXCEPTION 'La receta no desconto la materia prima: % -> %',
      v_component_stock_before, v_stock_after;
  END IF;
  SELECT quantity_on_hand INTO v_stock_after
  FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_packaging_item;
  IF v_stock_after <> v_packaging_stock_before - 1 THEN
    RAISE EXCEPTION 'La venta no desconto el empaque: % -> %',
      v_packaging_stock_before, v_stock_after;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sale_items WHERE id = v_line_id AND item_id = v_item.id)
     OR NOT EXISTS (SELECT 1 FROM public.inventory_movements
       WHERE id = 'qa-e2e-movement-' || substr(v_sale_id::text, 1, 8)
       AND item_id = v_item.id)
     OR NOT EXISTS (SELECT 1 FROM public.inventory_movements
       WHERE id = 'qa-e2e-packaging-' || substr(v_sale_id::text, 1, 8)
       AND item_id = v_packaging_item AND movement_type = 'sale'
       AND reference_id = v_sale_id::text) THEN
    RAISE EXCEPTION 'La venta no persistio item_id en detalle/movimiento.';
  END IF;

  PERFORM public.app_register_inventory_adjustment_batch_v2(
    v_restaurant,
    jsonb_build_array(jsonb_build_object(
      'movement_id', 'qa-e2e-adjustment-in', 'item_id', v_item.id,
      'expected_quantity', (SELECT quantity_on_hand FROM public.inventory_stock
        WHERE restaurant_id = v_restaurant AND item_id = v_item.id),
      'counted_quantity', (SELECT quantity_on_hand + 1 FROM public.inventory_stock
        WHERE restaurant_id = v_restaurant AND item_id = v_item.id)
    )),
    'QA E2E entrada'
  );
  SELECT quantity_on_hand INTO v_stock_after
  FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_item.id;
  PERFORM public.app_register_inventory_adjustment_batch_v2(
    v_restaurant,
    jsonb_build_array(jsonb_build_object(
      'movement_id', 'qa-e2e-adjustment-out', 'item_id', v_item.id,
      'expected_quantity', v_stock_after,
      'counted_quantity', v_stock_after - 1
    )),
    'QA E2E salida'
  );
  SELECT quantity_on_hand INTO v_stock_after
  FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_item.id;
  IF v_stock_after <> v_stock_before - 1 THEN
    RAISE EXCEPTION 'Los movimientos de ajuste no conservaron el stock esperado.';
  END IF;

  SELECT count(*) INTO v_report_rows
  FROM public.app_get_product_performance_report(
    v_restaurant, current_date - 30, current_date
  );
  IF v_report_rows < 0 THEN
    RAISE EXCEPTION 'Reporte de desempeño devolvio conteo invalido.';
  END IF;

  RAISE NOTICE 'E2E local OK: create/edit/codigo/recipe/packaging/POS/stock/adjustments/report';
END;
$$;

ROLLBACK;
