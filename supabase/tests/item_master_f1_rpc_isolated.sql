-- F1.1 assertions. Run only in the disposable lab after loading the DDL and RPC drafts.
-- The lab must provide auth.uid(), profiles, roles, permissions and role_permissions.
-- This file never commits test data and refuses an unmarked database.
BEGIN;
DO $$
DECLARE
  v_item uuid; v_service uuid; v_actor uuid := '30000000-0000-0000-0000-000000000001';
  v_digest text; v_when timestamptz; v_id text;
BEGIN
  IF current_setting('app.f1_isolated',true)<>'true' THEN
    RAISE EXCEPTION 'refusing_to_run_outside_isolated_lab';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
  SELECT (public.app_upsert_item('00000000-0000-0000-0000-000000000001',jsonb_build_object(
    'code','F11-TEST-INV','name','F11 Test Inventory','item_type','inventory',
    'base_unit_id','10000000-0000-0000-0000-000000000001','can_purchase',true))).id INTO v_item;
  SELECT (public.app_upsert_item('00000000-0000-0000-0000-000000000001',jsonb_build_object(
    'id',v_item,'name','F11 Renamed'))).id INTO v_item;
  IF NOT EXISTS (SELECT 1 FROM public.items WHERE id=v_item AND code='F11-TEST-INV'
    AND name='F11 Renamed' AND can_purchase) THEN RAISE EXCEPTION 'partial_update_failed'; END IF;

  v_when:=clock_timestamp();
  v_digest:=public.item_movement_request_digest('f11-open','00000000-0000-0000-0000-000000000001',v_item,'opening',3,'lab','open','f11-open',5,NULL,NULL,v_actor,v_when);
  PERFORM public.apply_item_movement('f11-open','00000000-0000-0000-0000-000000000001',v_item,'opening',3,'lab','open','f11-open',v_digest,5,NULL,NULL,v_actor,v_when);
  v_id:=(SELECT id FROM public.item_ledger_entries WHERE operation_key='f11-open');
  PERFORM public.apply_item_movement('f11-open','00000000-0000-0000-0000-000000000001',v_item,'opening',3,'lab','open','f11-open',v_digest,5,NULL,NULL,v_actor,v_when);
  IF (SELECT count(*) FROM public.item_ledger_entries WHERE operation_key='f11-open')<>1 THEN RAISE EXCEPTION 'idempotency_failed'; END IF;

  v_when:=clock_timestamp();
  v_digest:=public.item_movement_request_digest('f11-sale','00000000-0000-0000-0000-000000000001',v_item,'sale',-2,'lab','sale','f11-sale',5,NULL,NULL,v_actor,v_when);
  PERFORM public.apply_item_movement('f11-sale','00000000-0000-0000-0000-000000000001',v_item,'sale',-2,'lab','sale','f11-sale',v_digest,5,NULL,NULL,v_actor,v_when);
  v_when:=clock_timestamp();
  v_digest:=public.item_movement_request_digest('f11-reverse','00000000-0000-0000-0000-000000000001',v_item,'reversal',2,'lab','void','f11-reverse',5,'f11-sale',NULL,v_actor,v_when);
  PERFORM public.apply_item_movement('f11-reverse','00000000-0000-0000-0000-000000000001',v_item,'reversal',2,'lab','void','f11-reverse',v_digest,5,'f11-sale',NULL,v_actor,v_when);
  IF (SELECT quantity_on_hand FROM public.item_stock WHERE item_id=v_item)<>3 THEN RAISE EXCEPTION 'reversal_failed'; END IF;

  BEGIN
    v_when:=clock_timestamp(); v_digest:=public.item_movement_request_digest('f11-negative','00000000-0000-0000-0000-000000000001',v_item,'sale',-99,'lab','bad','f11-negative',5,NULL,NULL,v_actor,v_when);
    PERFORM public.apply_item_movement('f11-negative','00000000-0000-0000-0000-000000000001',v_item,'sale',-99,'lab','bad','f11-negative',v_digest,5,NULL,NULL,v_actor,v_when);
    RAISE EXCEPTION 'negative_stock_not_rejected';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'insufficient_stock' THEN RAISE; END IF; END;
  BEGIN
    PERFORM public.app_upsert_item('00000000-0000-0000-0000-000000000001',jsonb_build_object('id',v_item,'base_unit_id','10000000-0000-0000-0000-000000000003'));
    RAISE EXCEPTION 'base_unit_change_not_rejected';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'base_unit_change_blocked_by_movements' THEN RAISE; END IF; END;
  BEGIN
    UPDATE public.item_ledger_entries SET unit_cost_base=99 WHERE id=v_id;
    RAISE EXCEPTION 'ledger_update_not_rejected';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'item_ledger_append_only' THEN RAISE; END IF; END;
  RAISE NOTICE 'PASS F1.1 invariants: partial update, idempotency, reversal, stock, base unit, append-only';
END $$;

DO $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000002',true);
  BEGIN
    PERFORM public.apply_item_movement('f11-no-art-inv','00000000-0000-0000-0000-000000000001',
      (SELECT id FROM public.items WHERE code='F11-TEST-INV'),'sale',-1,'lab','x','f11-no-art-inv','x',1);
    RAISE EXCEPTION 'article_only_user_got_inventory_access';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'movement_not_authorized' THEN RAISE; END IF; END;
  RAISE NOTICE 'PASS permission separation';
END $$;

DO $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub','30000000-0000-0000-0000-000000000004',true);
  BEGIN
    PERFORM public.app_upsert_item('00000000-0000-0000-0000-000000000001',jsonb_build_object(
      'code','F11-POS','name','POS denied','item_type','inventory','base_unit_id','10000000-0000-0000-0000-000000000001'));
    RAISE EXCEPTION 'pos_user_got_item_access';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'item_write_not_authorized' THEN RAISE; END IF; END;
  RAISE NOTICE 'PASS POS rejection';
END $$;

ROLLBACK;
