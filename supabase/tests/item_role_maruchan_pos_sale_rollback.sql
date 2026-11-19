-- Local regression proof for existing commercial item 10. All writes roll back.
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
  v_updated_item public.items;
  v_sale_id uuid := gen_random_uuid();
  v_line_id uuid := gen_random_uuid();
  v_device_id uuid := gen_random_uuid();
  v_stale_device_id uuid := gen_random_uuid();
  v_device_secret text := 'qa-maruchan-device-secret-20261118';
  v_cash_session uuid;
  v_cashier uuid;
  v_payment uuid;
  v_sales_type uuid;
  v_before numeric;
  v_after numeric;
  v_reply jsonb;
  v_revision bigint;
  v_snapshot_id uuid;
  v_catalog jsonb;
  v_payload jsonb;
  v_stale_rejected boolean := false;
  v_operational_rejected boolean := false;
  v_second_sale_id uuid := gen_random_uuid();
  v_sale_price numeric;
BEGIN
  SELECT * INTO v_item FROM public.items
  WHERE restaurant_id = v_restaurant AND commercial_code = 10
    AND name = 'MARUCHAN' AND item_class = 'sale_product'
    AND item_type = 'inventory' AND tracks_inventory AND can_sell AND is_active;
  IF v_item.id IS NULL THEN
    RAISE EXCEPTION 'local_item_10_maruchan_fixture_not_found';
  END IF;
  SELECT id, cashier_user_id INTO v_cash_session, v_cashier
  FROM public.cash_register_sessions
  WHERE restaurant_id = v_restaurant AND status = 'open'
  LIMIT 1;
  SELECT id INTO v_payment FROM public.payment_methods
  WHERE restaurant_id = v_restaurant AND is_active LIMIT 1;
  SELECT id INTO v_sales_type FROM public.sales_types
  WHERE restaurant_id = v_restaurant AND is_active LIMIT 1;
  IF v_cash_session IS NULL OR v_cashier IS NULL OR v_payment IS NULL
     OR v_sales_type IS NULL THEN
    RAISE EXCEPTION 'local_pos_sale_fixtures_incomplete';
  END IF;
  PERFORM public.register_pos_device(
    v_restaurant, v_device_id, v_device_secret, 'QA MARUCHAN rollback'
  );
  v_catalog := public.pos_pull_item_catalog_v2(
    v_restaurant, v_device_id, v_device_secret
  );
  v_revision := (v_catalog ->> 'revision')::bigint;
  v_snapshot_id := (v_catalog ->> 'snapshot_id')::uuid;
  PERFORM public.pos_ack_item_catalog_v2(
    v_restaurant, v_device_id, v_device_secret,
    v_revision, v_snapshot_id, 3
  );
  IF NOT EXISTS (
    SELECT 1 FROM public.pos_devices
    WHERE id = v_device_id AND item_catalog_revision = v_revision
      AND item_catalog_snapshot_id = v_snapshot_id
      AND item_catalog_contract_version = 3
  ) THEN
    RAISE EXCEPTION 'local_pos_catalog_ack_not_persisted';
  END IF;
  PERFORM public.register_pos_device(
    v_restaurant, v_stale_device_id,
    'qa-stale-device-secret-long-20261118', 'QA stale catalog gate'
  );

  BEGIN
    PERFORM public.pos_sync_sale_v2(
      v_restaurant, v_device_id, v_device_secret,
      jsonb_build_object(
        'item_catalog_revision', v_revision - 1,
        'item_catalog_snapshot_id', gen_random_uuid(),
        'item_catalog_contract_version', 3
      )
    );
  EXCEPTION WHEN SQLSTATE '40001' THEN
    v_stale_rejected := SQLERRM = 'pos_catalog_revision_stale_refresh_required';
  END;
  IF NOT v_stale_rejected THEN
    RAISE EXCEPTION 'stale_catalog_sale_was_not_rejected';
  END IF;
  SELECT COALESCE(quantity_on_hand, 0) INTO v_before
  FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_item.id;
  IF COALESCE(v_before, 0) < 1 THEN
    RAISE EXCEPTION 'local_item_10_maruchan_stock_below_one';
  END IF;

  -- The POS has captured the sale-time price. A Backoffice price-only edit
  -- must not invalidate this pending sale or rewrite its captured amount.
  v_sale_price := v_item.base_unit_price;
  v_updated_item := public.app_upsert_item_v2(
    v_restaurant,
    to_jsonb(v_item) || jsonb_build_object(
      'base_unit_price', v_sale_price + 1
    )
  );

  v_payload := jsonb_build_object(
      'sale', jsonb_build_object(
        'id', v_sale_id, 'local_id', v_sale_id::text,
        'invoice_number', 'QA-MARUCHAN-' || substr(v_sale_id::text, 1, 8),
        'cash_register_session_id', v_cash_session, 'user_id', v_cashier,
        'payment_method_id', v_payment, 'sales_type_id', v_sales_type,
        'total_amount', v_sale_price,
        'total_cost', v_item.base_unit_cost,
        'gross_profit', v_sale_price - v_item.base_unit_cost,
        'status', 'completed', 'sold_at', now(), 'business_date', current_date
      ),
      'items', jsonb_build_array(jsonb_build_object(
        'id', v_line_id, 'item_id', v_item.id, 'product_code', v_item.code,
        'product_name', v_item.name, 'category_name', 'QA',
        'quantity', 1, 'unit_price', v_sale_price,
        'unit_cost', v_item.base_unit_cost, 'subtotal', v_sale_price,
        'gross_profit', v_sale_price - v_item.base_unit_cost
      )),
      'inventory_movements', jsonb_build_array(jsonb_build_object(
        'id', 'qa-maruchan-sale-' || v_sale_id::text,
        'item_id', v_item.id, 'movement_type', 'sale',
        'quantity_delta', -1, 'unit_cost', v_item.base_unit_cost,
        'reference_type', 'sale', 'reference_id', v_sale_id::text,
        'created_at', now()
      )),
      'item_catalog_revision', v_revision,
      'item_catalog_snapshot_id', v_snapshot_id,
      'item_catalog_contract_version', 3
    );
  v_reply := public.pos_sync_sale_v2(
    v_restaurant, v_device_id, v_device_secret, v_payload
  );
  IF (v_reply ->> 'remote_id')::uuid <> v_sale_id THEN
    RAISE EXCEPTION 'local_item_10_sale_not_acknowledged';
  END IF;
  SELECT quantity_on_hand INTO v_after FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_item.id;
  IF v_after <> v_before - 1 THEN
    RAISE EXCEPTION 'local_item_10_sale_stock_not_decremented: % -> %',
      v_before, v_after;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.sale_items
    WHERE id = v_line_id AND sale_id = v_sale_id AND item_id = v_item.id
  ) OR NOT EXISTS (
    SELECT 1 FROM public.inventory_movements
    WHERE id = 'qa-maruchan-sale-' || v_sale_id::text
      AND item_id = v_item.id AND movement_type = 'sale'
      AND quantity_delta = -1 AND reference_id = v_sale_id::text
  ) THEN
    RAISE EXCEPTION 'local_item_10_sale_detail_or_ledger_missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.sales
    WHERE id = v_sale_id AND item_catalog_revision = v_revision
      AND item_catalog_snapshot_id = v_snapshot_id
      AND item_catalog_contract_version = 3
  ) THEN
    RAISE EXCEPTION 'local_sale_catalog_identity_not_persisted';
  END IF;
  IF (SELECT total_amount FROM public.sales WHERE id = v_sale_id)
       IS DISTINCT FROM v_sale_price
     OR (SELECT unit_price FROM public.sale_items WHERE id = v_line_id)
       IS DISTINCT FROM v_sale_price
     OR (SELECT base_unit_price FROM public.items WHERE id = v_item.id)
       IS DISTINCT FROM v_sale_price + 1 THEN
    RAISE EXCEPTION 'sale_time_price_was_not_preserved_after_price_edit';
  END IF;

  -- Inventory-affecting edits remain incompatible with an old POS snapshot.
  v_updated_item := public.app_upsert_item_v2(
    v_restaurant,
    to_jsonb(v_updated_item) || jsonb_build_object(
      'can_sell', false, 'visible_in_pos', false
    )
  );
  v_payload := jsonb_set(v_payload, '{sale,id}', to_jsonb(v_second_sale_id), true);
  v_payload := jsonb_set(
    v_payload, '{sale,local_id}', to_jsonb(v_second_sale_id::text), true
  );
  v_payload := jsonb_set(
    v_payload, '{sale,invoice_number}',
    to_jsonb('QA-MARUCHAN-STALE-' || substr(v_second_sale_id::text, 1, 8)), true
  );
  v_payload := jsonb_set(
    v_payload, '{items,0,id}', to_jsonb(gen_random_uuid()), true
  );
  v_payload := jsonb_set(
    v_payload, '{inventory_movements,0,id}',
    to_jsonb('qa-maruchan-sale-' || v_second_sale_id::text), true
  );
  BEGIN
    PERFORM public.pos_sync_sale_v2(
      v_restaurant, v_device_id, v_device_secret, v_payload
    );
  EXCEPTION WHEN SQLSTATE '40001' THEN
    v_operational_rejected :=
      SQLERRM = 'pos_catalog_revision_stale_refresh_required';
  END;
  IF NOT v_operational_rejected OR EXISTS (
    SELECT 1 FROM public.sales WHERE id = v_second_sale_id
  ) THEN
    RAISE EXCEPTION 'stale_operational_sale_was_not_rejected_atomically';
  END IF;
  -- Restore the original identity for an idempotent retry after the later
  -- operational change; accepted sales must not be rejected on retry.
  v_payload := jsonb_set(v_payload, '{sale,id}', to_jsonb(v_sale_id), true);
  v_payload := jsonb_set(
    v_payload, '{sale,local_id}', to_jsonb(v_sale_id::text), true
  );
  v_payload := jsonb_set(
    v_payload, '{sale,invoice_number}',
    to_jsonb('QA-MARUCHAN-' || substr(v_sale_id::text, 1, 8)), true
  );
  v_payload := jsonb_set(v_payload, '{items,0,id}', to_jsonb(v_line_id), true);
  v_payload := jsonb_set(
    v_payload, '{inventory_movements,0,id}',
    to_jsonb('qa-maruchan-sale-' || v_sale_id::text), true
  );
  -- Retrying the identical queue payload after a lost response is idempotent.
  v_reply := public.pos_sync_sale_v2(
    v_restaurant, v_device_id, v_device_secret, v_payload
  );
  SELECT quantity_on_hand INTO v_after FROM public.inventory_stock
  WHERE restaurant_id = v_restaurant AND item_id = v_item.id;
  IF v_after <> v_before - 1 OR
     (SELECT count(*) FROM public.sales WHERE id = v_sale_id) <> 1 OR
     (SELECT count(*) FROM public.inventory_movements
      WHERE id = 'qa-maruchan-sale-' || v_sale_id::text) <> 1 THEN
    RAISE EXCEPTION 'idempotent_sale_retry_duplicated_sale_or_movement';
  END IF;
  RAISE NOTICE 'PASS: ack, stale rejection, price snapshot, operational stale rejection, idempotent retry; stock % -> %',
    v_before, v_after;
END;
$test$;

RESET ROLE;
DO $gate_test$
BEGIN
  BEGIN
    PERFORM item_core_internal.assert_pos_catalog_ack_current(
      '0f4e9ea0-948e-4d07-b2e0-55a96b3a462f'
    );
    RAISE EXCEPTION 'item_class_gate_did_not_reject_stale_device';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    IF SQLERRM <> 'item_class_change_requires_current_pos_catalog_ack' THEN
      RAISE;
    END IF;
  END;
END;
$gate_test$;
SET LOCAL ROLE authenticated;

ROLLBACK;
