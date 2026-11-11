-- Execute after fixture + F2 private-ledger draft, in same psql session.
DO $$
DECLARE
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_item uuid := '10000000-0000-0000-0000-000000000001';
  v_actor uuid := '30000000-0000-0000-0000-000000000001';
  v_time timestamptz := '2026-11-10T18:00:00Z';
  v_digest text;
  v_first text;
  v_repeat text;
  v_quantity numeric;
BEGIN
  v_digest := public.item_movement_request_digest(
    'm-opening',v_tenant,v_item,'opening',5,'test','opening-1',
    'op-opening',3,NULL,NULL,v_actor,v_time
  );
  SELECT id INTO v_first FROM public.apply_item_movement(
    'm-opening',v_tenant,v_item,'opening',5,'test','opening-1',
    'op-opening',v_digest,3,NULL,NULL,v_actor,v_time
  );
  SELECT id INTO v_repeat FROM public.apply_item_movement(
    'm-opening',v_tenant,v_item,'opening',5,'test','opening-1',
    'op-opening',v_digest,3,NULL,NULL,v_actor,v_time
  );
  IF v_first IS DISTINCT FROM v_repeat THEN
    RAISE EXCEPTION 'admin_wrapper_idempotency_failed';
  END IF;

  -- Simulate the future POS wrapper AFTER its own assert_pos_device/session.
  -- Only the definer, never the POS client itself, may invoke this core.
  PERFORM item_core_internal.post_movement(
    'm-sale',v_tenant,v_item,'sale',-2,'sale','sale-1',
    'op-sale',3,NULL,NULL,v_actor,v_time
  );
  PERFORM item_core_internal.post_movement(
    'm-reverse',v_tenant,v_item,'reversal',2,'sale_void','void-1',
    'op-void',3,'m-sale',NULL,v_actor,v_time
  );

  SELECT quantity_on_hand INTO v_quantity FROM public.item_stock
  WHERE restaurant_id=v_tenant AND item_id=v_item;
  IF v_quantity<>5 OR
     (SELECT count(*) FROM public.item_ledger_entries WHERE item_id=v_item)<>3
  THEN
    RAISE EXCEPTION 'shared_engine_balance_or_ledger_failed';
  END IF;

  BEGIN
    PERFORM item_core_internal.post_movement(
      'm-other-void',v_tenant,v_item,'reversal',2,'sale_void','void-2',
      'op-void-2',3,'m-sale',NULL,v_actor,v_time
    );
    RAISE EXCEPTION 'second_reversal_not_rejected';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    PERFORM item_core_internal.post_movement(
      'm-no-stock',v_tenant,
      '10000000-0000-0000-0000-000000000002','sale',-1,
      'sale','service-1','op-service',0,NULL,NULL,v_actor,v_time
    );
    RAISE EXCEPTION 'service_stock_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'item_not_active_or_not_inventory' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM item_core_internal.post_movement(
      'm-cross',v_tenant,
      '10000000-0000-0000-0000-000000000003','sale',-1,
      'sale','other-tenant','op-cross',0,NULL,NULL,v_actor,v_time
    );
    RAISE EXCEPTION 'cross_tenant_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'item_not_active_or_not_inventory' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM item_core_internal.post_movement(
      'm-negative',v_tenant,v_item,'sale',-6,'sale','negative-1',
      'op-negative',3,NULL,NULL,v_actor,v_time
    );
    RAISE EXCEPTION 'negative_stock_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'insufficient_stock' THEN RAISE; END IF;
  END;

  PERFORM set_config('app.can_write_inventory','false',true);
  BEGIN
    PERFORM public.apply_item_movement(
      'm-denied',v_tenant,v_item,'adjustment',1,
      'admin','blocked','op-blocked','not-a-digest',
      3,NULL,NULL,v_actor,v_time
    );
    RAISE EXCEPTION 'admin_permission_not_enforced';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'movement_not_authorized' THEN RAISE; END IF;
  END;
  PERFORM set_config('app.can_write_inventory','true',true);

  IF (
    SELECT quantity_on_hand FROM public.item_stock
    WHERE restaurant_id=v_tenant AND item_id=v_item
  ) <> (
    SELECT coalesce(sum(quantity_delta),0)
    FROM public.item_ledger_entries
    WHERE restaurant_id=v_tenant AND item_id=v_item
  ) THEN
    RAISE EXCEPTION 'stock_projection_mismatch';
  END IF;

  RAISE NOTICE 'PASS F2 core ledger: admin, internal sale, rollback, auth, stock, idempotency';
END;
$$;

SET LOCAL ROLE authenticated;
DO $$
BEGIN
  BEGIN
    PERFORM item_core_internal.post_movement(
      'm-direct','00000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'adjustment',1,'client','bypass','op-bypass',0,
      NULL,NULL,'30000000-0000-0000-0000-000000000001',
      '2026-11-10T18:00:00Z'::timestamptz
    );
    RAISE EXCEPTION 'private_engine_direct_access_not_blocked';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'PASS F2 private engine inaccessible to authenticated clients';
END;
$$;
RESET ROLE;
ROLLBACK;
