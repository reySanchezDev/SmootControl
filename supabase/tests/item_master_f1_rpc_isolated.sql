-- F1 RPC assertions. Run only in the disposable lab after setting:
--   SET app.f1_isolated = 'true';
-- It intentionally has no cleanup because the lab is disposable.
BEGIN;
DO $$
DECLARE
  v_item_id uuid;
  v_service_id uuid;
  operation_id text;
  retry_id text;
  observed numeric;
  classification_count integer;
BEGIN
  IF current_setting('app.f1_isolated', true) <> 'true' THEN
    RAISE EXCEPTION 'refusing_to_run_outside_isolated_lab';
  END IF;
  PERFORM set_config(
    'request.jwt.claims',
    '{"role":"authenticated","restaurant_id":"00000000-0000-0000-0000-000000000001","permissions":["articulos.gestionar"]}',
    true
  );
  PERFORM set_config(
    'app.restaurant_id', '00000000-0000-0000-0000-000000000001', true
  );

  SELECT (public.app_upsert_item(
    '00000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'code', 'F1-TEST-INV', 'name', 'F1 Test Inventory',
      'item_type', 'inventory',
      'base_unit_id', '10000000-0000-0000-0000-000000000002',
      'can_purchase', true,
      'classification_ids', ARRAY[
        (SELECT id FROM public.item_classifications WHERE code = 'ING')::text,
        (SELECT id FROM public.item_classifications WHERE code = 'PACK')::text
      ]
    )
  )).id INTO v_item_id;
  SELECT (public.app_upsert_item(
    '00000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'code', 'F1-TEST-SVC', 'name', 'F1 Test Service',
      'item_type', 'service',
      'base_unit_id', '10000000-0000-0000-0000-000000000001',
      'can_sell', true
    )
  )).id INTO v_service_id;

  SELECT count(*) INTO classification_count
  FROM public.item_classification_links AS links WHERE links.item_id = v_item_id;
  IF classification_count <> 2 THEN RAISE EXCEPTION 'classification_failed'; END IF;

  SELECT (public.apply_item_movement(
    'f1-test-opening', '00000000-0000-0000-0000-000000000001', v_item_id,
    'opening', 10, 'test', 'f1-opening', 'f1-op-1', 'f1-digest-1', 1
  )).id INTO operation_id;
  SELECT (public.apply_item_movement(
    'f1-test-retry', '00000000-0000-0000-0000-000000000001', v_item_id,
    'opening', 10, 'test', 'f1-opening', 'f1-op-1', 'f1-digest-1', 1
  )).id INTO retry_id;
  IF operation_id <> retry_id THEN RAISE EXCEPTION 'idempotency_failed'; END IF;

  PERFORM public.apply_item_movement(
    'f1-test-sale', '00000000-0000-0000-0000-000000000001', v_item_id,
    'sale', -4, 'test', 'f1-sale', 'f1-op-2', 'f1-digest-2', 1
  );
  PERFORM public.apply_item_movement(
    'f1-test-reversal', '00000000-0000-0000-0000-000000000001', v_item_id,
    'reversal', 4, 'test', 'f1-void', 'f1-op-3', 'f1-digest-3', 1,
    'f1-test-sale'
  );
  SELECT quantity_on_hand INTO observed FROM public.item_stock
  WHERE public.item_stock.item_id = v_item_id;
  IF observed <> 10 THEN RAISE EXCEPTION 'reversal_failed'; END IF;

  BEGIN
    PERFORM public.apply_item_movement(
      'f1-test-service', '00000000-0000-0000-0000-000000000001', v_service_id,
      'sale', 1, 'test', 'f1-service', 'f1-op-4', 'f1-digest-4', 0
    );
    RAISE EXCEPTION 'service_stock_not_rejected';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'item_type_has_no_physical_stock' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'PASS item master F1 RPC assertions';
END;
$$;
ROLLBACK;
