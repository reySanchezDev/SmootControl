-- PostgreSQL 16 isolated contract; POS fixture starts BEGIN.
DO $$
DECLARE
 t uuid:='00000000-0000-0000-0000-000000000001';
 foreign_t uuid:='00000000-0000-0000-0000-000000000002';
 original uuid:='90000000-0000-0000-0000-000000000001';
 other uuid:='90000000-0000-0000-0000-000000000002';
 fresh uuid:='90000000-0000-0000-0000-000000000010';
 product uuid:='30000000-0000-0000-0000-000000000001';
 start_snapshot uuid;
 v_row public.item_classifications;
BEGIN
 SELECT snapshot_id INTO start_snapshot
 FROM public.item_catalog_revisions WHERE restaurant_id=t;
 v_row:=public.app_upsert_item_classification_v2(
   t,original,'PACKAGING','Packaging',true
 );
 IF v_row.name<>'Packaging'
    OR (SELECT revision FROM public.item_catalog_revisions
        WHERE restaurant_id=t)<>2
    OR (SELECT snapshot_id FROM public.item_catalog_revisions
        WHERE restaurant_id=t)=start_snapshot THEN
   RAISE EXCEPTION 'classification_master_update_revision_failed';
 END IF;
 PERFORM public.app_upsert_item_classification_v2(
   t,original,'PACKAGING','Packaging',true
 );
 IF (SELECT revision FROM public.item_catalog_revisions
      WHERE restaurant_id=t)<>2 THEN
   RAISE EXCEPTION 'classification_master_replay_advanced_revision';
 END IF;
 BEGIN
   PERFORM public.app_upsert_item_classification_v2(
     t,fresh,'packaging','Duplicated',true
   );
   RAISE EXCEPTION 'classification_duplicate_allowed';
 EXCEPTION WHEN unique_violation THEN
   IF SQLERRM<>'duplicate_item_classification_code' THEN RAISE; END IF;
 END;
 BEGIN
   PERFORM public.app_upsert_item_classification_v2(
     t,other,'FOREIGN','Invalid',true
   );
   RAISE EXCEPTION 'classification_cross_tenant_id_allowed';
 EXCEPTION WHEN unique_violation THEN
   IF SQLERRM<>'classification_cross_tenant_id_collision' THEN RAISE; END IF;
 END;
 PERFORM public.app_set_item_classification_v2(t,product,original,true);
 BEGIN
   PERFORM public.app_upsert_item_classification_v2(
     t,original,'PACKAGING','Packaging',false
   );
   RAISE EXCEPTION 'assigned_classification_disabled';
 EXCEPTION WHEN check_violation THEN
   IF SQLERRM<>'classification_still_assigned' THEN RAISE; END IF;
 END;
 IF (SELECT revision FROM public.item_catalog_revisions
      WHERE restaurant_id=t)<>3 THEN
   RAISE EXCEPTION 'rejected_master_write_advanced_revision';
 END IF;
 PERFORM public.app_set_item_classification_v2(t,product,original,false);
 PERFORM public.app_upsert_item_classification_v2(
   t,original,'PACKAGING','Packaging',false
 );
 IF (SELECT revision FROM public.item_catalog_revisions
      WHERE restaurant_id=t)<>5 THEN
   RAISE EXCEPTION 'master_deactivation_not_revised';
 END IF;
 PERFORM set_config('app.can_write_inventory','false',true);
 BEGIN
   PERFORM public.app_upsert_item_classification_v2(
     t,fresh,'NEW','New',true
   );
   RAISE EXCEPTION 'classification_master_unauthorized_allowed';
 EXCEPTION WHEN insufficient_privilege THEN
   IF SQLERRM<>'item_classification_write_not_authorized' THEN RAISE; END IF;
 END;
 IF has_table_privilege('authenticated',
   'public.item_classifications','UPDATE') THEN
   RAISE EXCEPTION 'direct_classification_master_dml_allowed';
 END IF;
 IF NOT has_function_privilege(
   'authenticated',
   'public.app_upsert_item_classification_v2(uuid,uuid,text,text,boolean)',
   'EXECUTE') THEN
   RAISE EXCEPTION 'classification_master_rpc_not_granted';
 END IF;
 RAISE NOTICE 'PASS classification master: revision, replay, duplicate, tenant, references, permission';
END;
$$;
ROLLBACK;
