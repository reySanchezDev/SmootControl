-- Executes inside BEGIN from internal_ledger_fixture. Always ROLLBACK.
DO $$
DECLARE
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_item uuid := '10000000-0000-0000-0000-000000000001';
  v_service uuid := '10000000-0000-0000-0000-000000000002';
  v_other uuid := '10000000-0000-0000-0000-000000000003';
  v_base uuid := '80000000-0000-0000-0000-000000000001';
  v_box uuid := '80000000-0000-0000-0000-000000000002';
  v_time timestamptz := '2026-11-10T20:00:00Z';
  v_purchase_id uuid := '90000000-0000-0000-0000-000000000001';
  v_adjust_id uuid := '90000000-0000-0000-0000-000000000002';
  v_lines jsonb;
  v_result jsonb;
  v_count bigint;
BEGIN
  v_lines := jsonb_build_array(jsonb_build_object(
    'item_id',v_item,'unit_id',v_box,
    'quantity',2,'unit_cost',60
  ));
  v_result := public.app_post_item_stock_document_v2(
    v_tenant,v_purchase_id,'purchase-1','purchase',v_lines,v_time
  );
  IF v_result->>'replayed'<>'false'
     OR (v_result->>'posted_lines')::int<>1 THEN
    RAISE EXCEPTION 'purchase_result_incorrect';
  END IF;
  IF (SELECT quantity_on_hand FROM public.item_stock
      WHERE item_id=v_item) <> 24
     OR NOT EXISTS (
       SELECT 1 FROM public.item_ledger_entries
       WHERE item_id=v_item AND quantity_delta=24
         AND unit_cost_base=5 AND movement_type='purchase'
     ) THEN
    RAISE EXCEPTION 'purchase_unit_conversion_failed';
  END IF;

  v_result := public.app_post_item_stock_document_v2(
    v_tenant,v_purchase_id,'purchase-1','purchase',v_lines,v_time
  );
  IF v_result->>'replayed'<>'true'
     OR (SELECT count(*) FROM public.item_ledger_entries)<>1 THEN
    RAISE EXCEPTION 'purchase_replayed_duplicate_stock';
  END IF;

  BEGIN
    PERFORM public.app_post_item_stock_document_v2(
      v_tenant,v_purchase_id,'purchase-1','purchase',
      jsonb_set(v_lines,'{0,quantity}','3'::jsonb),v_time
    );
    RAISE EXCEPTION 'changed_purchase_replay_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'stock_document_idempotency_mismatch' THEN RAISE; END IF;
  END;

  v_lines := jsonb_build_array(jsonb_build_object(
    'item_id',v_item,'unit_id',v_base,
    'quantity',20,'expected_stock',24
  ));
  v_result:=public.app_post_item_stock_document_v2(
    v_tenant,v_adjust_id,'adjust-1','adjustment',v_lines,v_time
  );
  IF v_result->>'replayed'<>'false'
     OR (SELECT quantity_on_hand FROM public.item_stock
         WHERE item_id=v_item)<>20
     OR NOT EXISTS (
       SELECT 1 FROM public.item_ledger_entries
       WHERE movement_type='adjustment' AND quantity_delta=-4
     ) THEN
    RAISE EXCEPTION 'adjustment_not_applied';
  END IF;

  BEGIN
    PERFORM public.app_post_item_stock_document_v2(
      v_tenant,'90000000-0000-0000-0000-000000000003',
      'adjust-stale','adjustment',v_lines,v_time
    );
    RAISE EXCEPTION 'stale_count_not_rejected';
  EXCEPTION WHEN serialization_failure THEN
    IF SQLERRM<>'adjustment_stock_changed' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.app_post_item_stock_document_v2(
      v_tenant,'90000000-0000-0000-0000-000000000004',
      'bad-service','purchase',
      jsonb_build_array(jsonb_build_object(
        'item_id',v_service,'unit_id',v_base,
        'quantity',1,'unit_cost',5)),v_time
    );
    RAISE EXCEPTION 'service_purchase_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'stock_document_requires_inventory_item' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.app_post_item_stock_document_v2(
      v_tenant,'90000000-0000-0000-0000-000000000005',
      'bad-tenant','purchase',
      jsonb_build_array(jsonb_build_object(
        'item_id',v_other,'unit_id',v_base,
        'quantity',1,'unit_cost',5)),v_time
    );
    RAISE EXCEPTION 'cross_tenant_item_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'stock_document_requires_inventory_item' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.app_post_item_stock_document_v2(
      v_tenant,'90000000-0000-0000-0000-000000000006',
      'bad-duplicate','purchase',
      jsonb_build_array(
        jsonb_build_object(
          'item_id',v_item,'unit_id',v_box,'quantity',1,'unit_cost',1
        ),
        jsonb_build_object(
          'item_id',v_item,'unit_id',v_box,'quantity',1,'unit_cost',1
        )
      ),v_time
    );
    RAISE EXCEPTION 'duplicate_item_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'duplicate_stock_document_item' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.app_post_item_stock_document_v2(
      v_tenant,'90000000-0000-0000-0000-000000000007',
      'bad-precision','purchase',
      jsonb_build_array(jsonb_build_object(
        'item_id',v_item,'unit_id',v_box,
        'quantity',0.00000001,'unit_cost',5
      )),v_time
    );
    RAISE EXCEPTION 'precision_loss_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'stock_document_precision_loss' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM set_config('app.can_write_inventory','false',true);
    PERFORM public.app_post_item_stock_document_v2(
      v_tenant,'90000000-0000-0000-0000-000000000008',
      'no-permission','purchase',
      jsonb_build_array(jsonb_build_object(
        'item_id',v_item,'unit_id',v_box,'quantity',1,'unit_cost',5
      )),v_time
    );
    RAISE EXCEPTION 'unauthorized_purchase_not_rejected';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM<>'stock_document_not_authorized' THEN RAISE; END IF;
  END;
  PERFORM set_config('app.can_write_inventory','true',true);

  SELECT count(*) INTO v_count FROM public.item_inventory_operations;
  IF v_count <> 2
     OR (SELECT count(*) FROM public.item_ledger_entries)<>2
     OR (SELECT quantity_on_hand FROM public.item_stock WHERE item_id=v_item)<>20
     OR (SELECT COALESCE(sum(quantity_delta),0)
         FROM public.item_ledger_entries WHERE item_id=v_item)<>20 THEN
    RAISE EXCEPTION 'failed_document_left_partial_effects';
  END IF;

  RAISE NOTICE 'PASS F2 stock documents: purchase unit/cost, count adjustment, replay, tenant, service, duplicate, precision, permission, rollback';
END;
$$;
ROLLBACK;
