-- Local contract proof; all article and catalog changes roll back.
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config(
  'request.jwt.claims',
  '{"sub":"b096e0cb-2a63-4559-960f-0db22b260b85","restaurant_id":"0f4e9ea0-948e-4d07-b2e0-55a96b3a462f"}',
  true
);

DO $test$
DECLARE
  v_restaurant uuid := '0f4e9ea0-948e-4d07-b2e0-55a96b3a462f';
  v_unit uuid;
  v_inventory public.items;
  v_non_inventory public.items;
  v_service public.items;
  v_updated public.items;
  v_existing_stock public.items;
BEGIN
  SELECT id INTO v_unit FROM public.measurement_units
  WHERE restaurant_id = v_restaurant AND is_active LIMIT 1;
  IF v_unit IS NULL THEN RAISE EXCEPTION 'active_unit_fixture_missing'; END IF;

  v_inventory := public.app_upsert_item_v2(v_restaurant, jsonb_build_object(
    'name', 'QA Type Stock ' || gen_random_uuid(),
    'item_type', 'inventory', 'item_class', 'sale_product',
    'tracks_inventory', false, 'commercial_code', 999999999,
    'base_unit_id', v_unit, 'can_sell', true, 'can_purchase', true,
    'visible_in_pos', true, 'is_active', true
  ));
  IF NOT v_inventory.tracks_inventory
     OR v_inventory.commercial_code = 999999999
     OR v_inventory.code !~ '^ART-[0-9]+$'
  THEN RAISE EXCEPTION 'inventory_type_or_server_code_authority_failed'; END IF;

  v_updated := public.app_upsert_item_v2(v_restaurant, jsonb_build_object(
    'id', v_inventory.id, 'name', 'QA Type Stock Edited',
    'item_type', 'inventory', 'item_class', 'sale_product',
    'tracks_inventory', false, 'commercial_code', 888888888,
    'base_unit_id', v_unit, 'can_sell', true, 'can_purchase', true,
    'visible_in_pos', true, 'is_active', true
  ));
  IF NOT v_updated.tracks_inventory
     OR v_updated.commercial_code <> v_inventory.commercial_code
     OR v_updated.code <> v_inventory.code THEN
    RAISE EXCEPTION 'edit_changed_derived_stock_or_business_codes';
  END IF;

  v_non_inventory := public.app_upsert_item_v2(v_restaurant, jsonb_build_object(
    'name', 'QA Non Inventory ' || gen_random_uuid(),
    'item_type', 'non_inventory', 'item_class', 'packaging',
    'tracks_inventory', true, 'base_unit_id', v_unit,
    'can_purchase', true, 'is_active', true
  ));
  IF v_non_inventory.tracks_inventory THEN
    RAISE EXCEPTION 'non_inventory_type_created_with_stock_tracking';
  END IF;
  IF v_non_inventory.commercial_code <> v_inventory.commercial_code + 1 THEN
    RAISE EXCEPTION 'commercial_code_not_sequential';
  END IF;

  v_service := public.app_upsert_item_v2(v_restaurant, jsonb_build_object(
    'name', 'QA Service ' || gen_random_uuid(),
    'item_type', 'service', 'item_class', 'service',
    'tracks_inventory', true, 'uses_recipe', true,
    'base_unit_id', v_unit, 'is_active', true
  ));
  IF v_service.tracks_inventory OR v_service.uses_recipe
     OR v_service.item_class <> 'service'
     OR v_service.commercial_code <> v_non_inventory.commercial_code + 1 THEN
    RAISE EXCEPTION 'service_contract_not_derived';
  END IF;

  SELECT item.* INTO v_existing_stock
  FROM public.items item
  JOIN public.inventory_stock stock
    ON stock.restaurant_id = item.restaurant_id
   AND stock.item_id = item.id
   AND stock.quantity_on_hand > 0
  WHERE item.restaurant_id = v_restaurant
    AND item.item_class = 'sale_product'
    AND item.tracks_inventory
  LIMIT 1;
  IF v_existing_stock.id IS NULL THEN
    RAISE EXCEPTION 'positive_sale_product_stock_fixture_missing';
  END IF;
  BEGIN
    PERFORM public.app_upsert_item_v2(v_restaurant, jsonb_build_object(
      'id', v_existing_stock.id, 'name', v_existing_stock.name,
      'item_type', 'non_inventory', 'item_class', v_existing_stock.item_class,
      'base_unit_id', v_existing_stock.base_unit_id,
      'can_sell', v_existing_stock.can_sell,
      'can_purchase', v_existing_stock.can_purchase,
      'visible_in_pos', v_existing_stock.visible_in_pos,
      'uses_recipe', v_existing_stock.uses_recipe,
      'send_to_kitchen', v_existing_stock.send_to_kitchen,
      'is_active', v_existing_stock.is_active
    ));
    RAISE EXCEPTION 'nonzero_stock_item_type_change_was_accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  IF NOT EXISTS (
    SELECT 1 FROM public.items
    WHERE id = v_existing_stock.id AND item_type = 'inventory'
      AND tracks_inventory
  ) THEN RAISE EXCEPTION 'blocked_type_change_mutated_item'; END IF;

  BEGIN
    PERFORM public.app_upsert_item_v2(v_restaurant, jsonb_build_object(
      'id', v_inventory.id, 'name', 'Invalid role conversion',
      'item_type', 'inventory', 'item_class', 'packaging',
      'base_unit_id', v_unit, 'is_active', true
    ));
    RAISE EXCEPTION 'operational_role_conversion_was_accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  IF has_function_privilege(
       'authenticated',
       'public.app_upsert_item_v2_pre_128(uuid,jsonb)', 'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'pre_contract_writer_exposed_to_clients';
  END IF;
  RAISE NOTICE 'PASS: type-derived stock, generated immutable codes, service, role identity, authenticated RPC';
END;
$test$;

RESET ROLE;
UPDATE public.items
SET tracks_inventory = false
WHERE name = 'QA Type Stock Edited';
DO $projection$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.items
    WHERE name = 'QA Type Stock Edited'
      AND item_type = 'inventory' AND tracks_inventory
  ) THEN RAISE EXCEPTION 'database_did_not_derive_inventory_flag'; END IF;
END;
$projection$;
ROLLBACK;
