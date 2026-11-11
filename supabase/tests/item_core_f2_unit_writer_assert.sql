-- Always ends with ROLLBACK; never touches operating data.
INSERT INTO public.item_catalog_revisions(restaurant_id)
VALUES('00000000-0000-0000-0000-000000000001');
DO $$
DECLARE
 t uuid:='00000000-0000-0000-0000-000000000001';
 item uuid:='30000000-0000-0000-0000-000000000001';
 bag uuid:='30000000-0000-0000-0000-000000000002';
 base uuid:='10000000-0000-0000-0000-000000000001';
 dozen uuid:='10000000-0000-0000-0000-000000000002';
 other_dimension uuid:='10000000-0000-0000-0000-000000000003';
 other_tenant uuid:='10000000-0000-0000-0000-000000000004';
 snap uuid;
 r bigint;
BEGIN
 SELECT snapshot_id INTO snap FROM public.item_catalog_revisions WHERE restaurant_id=t;
 PERFORM public.app_upsert_item_unit_v2(t,item,dozen,12,true,true,true);
 IF (SELECT revision FROM public.item_catalog_revisions WHERE restaurant_id=t)<>2
 OR (SELECT snapshot_id FROM public.item_catalog_revisions WHERE restaurant_id=t)=snap THEN
   RAISE EXCEPTION 'unit_change_did_not_advance_revision';
 END IF;
 PERFORM public.app_upsert_item_unit_v2(t,item,dozen,12,true,true,true);
 IF (SELECT revision FROM public.item_catalog_revisions WHERE restaurant_id=t)<>2 THEN
   RAISE EXCEPTION 'identical_replay_advanced_revision';
 END IF;
 IF NOT EXISTS(
   SELECT 1 FROM jsonb_array_elements(public.pos_pull_item_catalog_v2(
     t,'50000000-0000-0000-0000-000000000001','fixture-secret'
   )->'item_units') x
   WHERE x->>'unit_id'=dozen::text
     AND (x->>'quantity_in_base')::numeric=12
 ) THEN RAISE EXCEPTION 'unit_not_published_in_snapshot'; END IF;

 BEGIN
  PERFORM public.app_upsert_item_unit_v2(t,item,base,2,false,false,true);
  RAISE EXCEPTION 'invalid_base_allowed';
 EXCEPTION WHEN check_violation THEN
  IF SQLERRM<>'item_unit_base_must_be_active_one' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.app_upsert_item_unit_v2(t,item,other_dimension,1,false,false,true);
  RAISE EXCEPTION 'invalid_dimension_allowed';
 EXCEPTION WHEN check_violation THEN
  IF SQLERRM<>'item_unit_invalid_dimension_or_tenant' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.app_upsert_item_unit_v2(t,item,other_tenant,1,false,false,true);
  RAISE EXCEPTION 'cross_tenant_unit_allowed';
 EXCEPTION WHEN check_violation THEN
  IF SQLERRM<>'item_unit_invalid_dimension_or_tenant' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.app_upsert_item_unit_v2(t,bag,base,1,false,false,false);
  RAISE EXCEPTION 'disabled_base_allowed';
 EXCEPTION WHEN check_violation THEN
  IF SQLERRM<>'item_unit_base_must_be_active_one' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.app_upsert_item_unit_v2(t,item,dozen,'NaN'::numeric,true,true,true);
  RAISE EXCEPTION 'nan_allowed';
 EXCEPTION WHEN invalid_parameter_value THEN
  IF SQLERRM<>'invalid_item_unit_fields' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.app_upsert_item_unit_v2(t,item,base,1,true,true,true);
  RAISE EXCEPTION 'duplicate_purchase_or_sale_allowed';
 EXCEPTION WHEN unique_violation THEN
  IF SQLERRM<>'item_unit_purchase_already_assigned' THEN RAISE; END IF;
 END;
 IF (SELECT revision FROM public.item_catalog_revisions WHERE restaurant_id=t)<>2 THEN
  RAISE EXCEPTION 'rejected_unit_mutated_revision';
 END IF;
 PERFORM set_config('app.can_write_inventory','false',true);
 BEGIN
  PERFORM public.app_upsert_item_unit_v2(t,item,dozen,24,true,true,true);
  RAISE EXCEPTION 'unauthorized_unit_write_allowed';
 EXCEPTION WHEN insufficient_privilege THEN
  IF SQLERRM<>'item_unit_write_not_authorized' THEN RAISE; END IF;
 END;
 IF has_table_privilege('authenticated','public.item_units','UPDATE') THEN
  RAISE EXCEPTION 'unit_direct_dml_exposed';
 END IF;
 IF NOT has_function_privilege('authenticated',
  'public.app_upsert_item_unit_v2(uuid,uuid,uuid,numeric,boolean,boolean,boolean)',
  'EXECUTE') THEN RAISE EXCEPTION 'unit_writer_rpc_not_granted'; END IF;
 RAISE NOTICE 'PASS F2 unit writer: revisions, replay, scope, base unit, privileges';
END;
$$;
ROLLBACK;
