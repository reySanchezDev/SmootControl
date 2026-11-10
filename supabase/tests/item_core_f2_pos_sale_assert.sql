-- Contract test: one atomic simple sale + packaging + void + replay.
-- Executes inside transaction begun by the isolated POS fixture.
DO $$
DECLARE
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_device uuid := '50000000-0000-0000-0000-000000000001';
  v_cashier uuid := '70000000-0000-0000-0000-000000000001';
  v_bottle uuid := '30000000-0000-0000-0000-000000000001';
  v_bag uuid := '30000000-0000-0000-0000-000000000002';
  v_sale uuid := '90000000-0000-0000-0000-000000000001';
  v_void uuid := '92000000-0000-0000-0000-000000000001';
  v_time timestamptz := '2026-11-10T19:00:00Z';
  v_payload jsonb;
  v_void_payload jsonb;
  v_result jsonb;
  v_rows integer;
BEGIN
  -- Opening stock is not part of the sale or void; it must stay intact.
  PERFORM item_core_internal.post_movement(
    'opening-bottle',v_tenant,v_bottle,'opening',10,
    'opening','opening-1','opening-bottle-key',3,NULL,
    v_device,v_cashier,v_time
  );
  PERFORM item_core_internal.post_movement(
    'opening-bag',v_tenant,v_bag,'opening',10,
    'opening','opening-1','opening-bag-key',1,NULL,
    v_device,v_cashier,v_time
  );

  v_payload := jsonb_build_object(
    'contract_version',2,
    'sale_id',v_sale,
    'operation_key','sale-01',
    'cash_register_session_id','60000000-0000-0000-0000-000000000001',
    'payment_method_id','80000000-0000-0000-0000-000000000001',
    'sales_type_id','20000000-0000-0000-0000-000000000001',
    'sold_at',v_time,
    'lines',jsonb_build_array(
      jsonb_build_object(
        'line_id','91000000-0000-0000-0000-000000000001',
        'item_id',v_bottle,'quantity',2,
        'unit_id','10000000-0000-0000-0000-000000000001',
        'unit_price',7
      ),
      jsonb_build_object(
        'line_id','91000000-0000-0000-0000-000000000002',
        'item_id','30000000-0000-0000-0000-000000000003',
        'quantity',1,
        'unit_id','10000000-0000-0000-0000-000000000001',
        'unit_price',5
      )
    )
  );

  v_result := public.pos_sync_sale_v2(
    v_tenant,v_device,'fixture-secret',v_payload
  );
  IF v_result->>'invoice_number' <> 'F-1'
     OR v_result->>'replayed' <> 'false' THEN
    RAISE EXCEPTION 'unexpected_sale_invoice_or_status: %',v_result;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.sales
    WHERE id=v_sale AND total_amount=19 AND total_cost=7
      AND gross_profit=12 AND operation_digest=md5(v_payload::text)
      AND sync_contract_version=2
  ) THEN RAISE EXCEPTION 'sale_header_snapshot_failed'; END IF;

  IF (SELECT count(*) FROM public.sale_items WHERE sale_id=v_sale)<>2
     OR NOT EXISTS(
       SELECT 1 FROM public.sale_items
       WHERE sale_id=v_sale AND product_code='BOT-1'
         AND product_name='Botella' AND category_name='Bebidas'
     )
  THEN RAISE EXCEPTION 'sale_item_snapshots_failed'; END IF;

  IF (SELECT quantity_on_hand FROM public.item_stock
      WHERE item_id=v_bottle)<>8
     OR (SELECT quantity_on_hand FROM public.item_stock
      WHERE item_id=v_bag)<>9
     OR (SELECT count(*) FROM public.item_ledger_entries
      WHERE source_type='sale' AND source_id=v_sale::text)<>2
     OR NOT EXISTS (
       SELECT 1 FROM public.sale_consumption_snapshots
       WHERE sale_id=v_sale AND quantity_base=1 AND scope='per_order'
     ) THEN RAISE EXCEPTION 'sale_stock_or_packaging_failed'; END IF;

  v_result:=public.pos_sync_sale_v2(
    v_tenant,v_device,'fixture-secret',v_payload
  );
  IF v_result->>'replayed' <> 'true'
     OR (SELECT count(*) FROM public.item_ledger_entries
         WHERE source_type='sale' AND source_id=v_sale::text)<>2
  THEN RAISE EXCEPTION 'sale_replay_duplicated_inventory'; END IF;

  BEGIN
    PERFORM public.pos_sync_sale_v2(
      v_tenant,v_device,'fixture-secret',
      jsonb_set(v_payload,'{lines,0,quantity}','3'::jsonb)
    );
    RAISE EXCEPTION 'modified_replay_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'sale_v2_idempotency_mismatch' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.pos_sync_sale_v2(
      v_tenant,v_device,'fixture-secret',
      jsonb_build_object(
        'contract_version',2,
        'sale_id','90000000-0000-0000-0000-000000000002',
        'operation_key','sale-insufficient',
        'cash_register_session_id',
        '60000000-0000-0000-0000-000000000001',
        'payment_method_id','80000000-0000-0000-0000-000000000001',
        'sales_type_id','20000000-0000-0000-0000-000000000001',
        'sold_at',v_time,
        'lines',jsonb_build_array(jsonb_build_object(
          'line_id','91000000-0000-0000-0000-000000000003',
          'item_id',v_bottle,'quantity',99,
          'unit_id','10000000-0000-0000-0000-000000000001'
        ))
      )
    );
    RAISE EXCEPTION 'insufficient_sale_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'insufficient_stock' THEN RAISE; END IF;
  END;
  IF EXISTS(SELECT 1 FROM public.sales WHERE operation_key='sale-insufficient')
     OR (SELECT next_number FROM public.invoice_number_settings
         WHERE restaurant_id=v_tenant)<>2
  THEN RAISE EXCEPTION 'failed_sale_not_rolled_back_atomically'; END IF;

  -- Change current rule; void must reverse the posted ledger, not re-resolve.
  UPDATE public.item_consumption_rules SET quantity=4
    WHERE id='40000000-0000-0000-0000-000000000001';

  v_void_payload:=jsonb_build_object(
    'contract_version',2,'sale_id',v_sale,'void_id',v_void,
    'operation_key','void-01','reason','Anulacion de prueba',
    'voided_at','2026-11-10T20:00:00Z'
  );
  v_result:=public.pos_void_sale_v2(
    v_tenant,v_device,'fixture-secret',v_void_payload
  );
  IF v_result->>'replayed'<>'false'
     OR (SELECT quantity_on_hand FROM public.item_stock
         WHERE item_id=v_bottle)<>10
     OR (SELECT quantity_on_hand FROM public.item_stock
         WHERE item_id=v_bag)<>10
     OR (SELECT count(*) FROM public.item_ledger_entries
         WHERE movement_type='reversal')<>2
     OR (SELECT status FROM public.sales WHERE id=v_sale)<>'voided'
     OR (SELECT quantity_base FROM public.sale_consumption_snapshots
         WHERE sale_id=v_sale)<>1
  THEN RAISE EXCEPTION 'void_not_exactly_reversed'; END IF;

  v_result:=public.pos_void_sale_v2(
    v_tenant,v_device,'fixture-secret',v_void_payload
  );
  IF v_result->>'replayed'<>'true'
     OR (SELECT count(*) FROM public.item_ledger_entries
         WHERE movement_type='reversal')<>2
  THEN RAISE EXCEPTION 'void_replay_duplicate'; END IF;

  BEGIN
    PERFORM public.pos_void_sale_v2(
      v_tenant,v_device,'fixture-secret',
      jsonb_set(v_void_payload,'{reason}','"Razon modificada"'::jsonb)
    );
    RAISE EXCEPTION 'void_mismatch_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'void_v2_idempotency_mismatch' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.pos_sync_sale_v2(
      v_tenant,v_device,'incorrect-secret',v_payload
    );
    RAISE EXCEPTION 'device_secret_not_enforced';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'invalid_device_credentials' THEN RAISE; END IF;
  END;

  RAISE NOTICE 'PASS F2 atomic sale/void: totals, snapshots, stock, packaging, replay, negative rollback, device';
END;
$$;
ROLLBACK;
