-- Local-only proof: canonical packaging inventory uses the common item ledger.
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
  v_item public.items;
  v_before numeric;
  v_after_purchase numeric;
  v_after_adjustment numeric;
  v_purchase_id text := gen_random_uuid()::text;
  v_adjustment_id text := gen_random_uuid()::text;
BEGIN
  SELECT * INTO v_item FROM public.items
  WHERE restaurant_id = v_restaurant AND item_class = 'packaging'
    AND tracks_inventory AND is_active
  ORDER BY name LIMIT 1;
  IF v_item.id IS NULL THEN
    RAISE EXCEPTION 'tracked_packaging_fixture_missing';
  END IF;

  SELECT quantity_on_hand INTO v_before FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_item.id;
  v_before := COALESCE(v_before, 0);

  PERFORM public.app_register_inventory_purchase_batch_v2(
    v_restaurant,
    jsonb_build_array(jsonb_build_object(
      'movement_id', v_purchase_id, 'item_id', v_item.id,
      'quantity', 5, 'unit_cost', 1.25
    ))
  );
  SELECT quantity_on_hand INTO v_after_purchase FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_item.id;
  IF v_after_purchase <> v_before + 5 THEN
    RAISE EXCEPTION 'canonical_packaging_purchase_stock_mismatch';
  END IF;

  PERFORM public.app_register_inventory_adjustment_batch_v2(
    v_restaurant,
    jsonb_build_array(jsonb_build_object(
      'movement_id', v_adjustment_id, 'item_id', v_item.id,
      'expected_quantity', v_after_purchase,
      'counted_quantity', v_after_purchase + 2
    )),
    'QA inventario unificado'
  );
  SELECT quantity_on_hand INTO v_after_adjustment FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_item.id;
  IF v_after_adjustment <> v_after_purchase + 2 THEN
    RAISE EXCEPTION 'canonical_packaging_adjustment_stock_mismatch';
  END IF;
  IF (SELECT count(*) FROM public.inventory_movements
      WHERE restaurant_id = v_restaurant AND item_id = v_item.id
        AND id IN (v_purchase_id, v_adjustment_id)) <> 2 THEN
    RAISE EXCEPTION 'canonical_packaging_ledger_entries_missing';
  END IF;

  RAISE NOTICE 'PASS: canonical packaging purchase, adjustment, stock and ledger';
END;
$test$;

ROLLBACK;
