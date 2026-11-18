-- Complete isolation: POS fixture begins and this file rolls back.
DO $$
DECLARE
 t uuid:='00000000-0000-0000-0000-000000000001';
 v_item uuid:='30000000-0000-0000-0000-000000000002';
 cls uuid:='90000000-0000-0000-0000-000000000001';
 foreign_cls uuid:='90000000-0000-0000-0000-000000000002';
 inactive_cls uuid:='90000000-0000-0000-0000-000000000003';
 snapshot_before uuid;
BEGIN
 SELECT snapshot_id INTO snapshot_before
 FROM public.item_catalog_revisions WHERE restaurant_id=t;
  IF NOT public.app_set_item_classification_v2(t,v_item,cls,true) THEN
   RAISE EXCEPTION 'classification_link_not_created';
 END IF;
 IF (SELECT revision FROM public.item_catalog_revisions
      WHERE restaurant_id=t)<>2
    OR (SELECT snapshot_id FROM public.item_catalog_revisions
      WHERE restaurant_id=t)=snapshot_before THEN
   RAISE EXCEPTION 'classification_revision_not_advanced';
 END IF;
  IF public.app_set_item_classification_v2(t,v_item,cls,true) THEN
   RAISE EXCEPTION 'classification_replay_modified';
 END IF;
 IF (SELECT revision FROM public.item_catalog_revisions
      WHERE restaurant_id=t)<>2 THEN
   RAISE EXCEPTION 'classification_replay_bumped_revision';
 END IF;
 BEGIN
   PERFORM public.app_set_item_classification_v2(t,v_item,foreign_cls,true);
  RAISE EXCEPTION 'cross_tenant_classification_allowed';
 EXCEPTION WHEN check_violation THEN
  IF SQLERRM<>'item_classification_invalid_target' THEN RAISE; END IF;
 END;
 BEGIN
   PERFORM public.app_set_item_classification_v2(t,v_item,inactive_cls,true);
  RAISE EXCEPTION 'inactive_classification_allowed';
 EXCEPTION WHEN check_violation THEN
  IF SQLERRM<>'item_classification_invalid_target' THEN RAISE; END IF;
 END;
 IF (SELECT revision FROM public.item_catalog_revisions
      WHERE restaurant_id=t)<>2 THEN
   RAISE EXCEPTION 'rejected_classification_bumped_revision';
 END IF;
  IF NOT public.app_set_item_classification_v2(t,v_item,cls,false) THEN
    RAISE EXCEPTION 'classification_link_not_removed';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.item_classification_links
    WHERE restaurant_id=t AND item_id=v_item AND classification_id=cls
  ) THEN
    RAISE EXCEPTION 'classification_link_not_removed';
 END IF;
 IF (SELECT revision FROM public.item_catalog_revisions
      WHERE restaurant_id=t)<>3 THEN
   RAISE EXCEPTION 'classification_remove_no_revision';
 END IF;
  IF public.app_set_item_classification_v2(t,v_item,cls,false) THEN
   RAISE EXCEPTION 'classification_remove_replay_modified';
 END IF;
 PERFORM set_config('app.can_write_inventory','false',true);
 BEGIN
   PERFORM public.app_set_item_classification_v2(t,v_item,cls,true);
  RAISE EXCEPTION 'classification_permission_bypassed';
 EXCEPTION WHEN insufficient_privilege THEN
  IF SQLERRM<>'item_classification_not_authorized' THEN RAISE; END IF;
 END;
 IF has_table_privilege('authenticated',
     'public.item_classification_links','INSERT') OR
    has_table_privilege('authenticated',
     'public.item_classification_links','DELETE') THEN
   RAISE EXCEPTION 'classification_direct_dml_exposed';
 END IF;
 RAISE NOTICE 'PASS F2 classification link: revision, replay, remove, tenant, permission';
END;
$$;
ROLLBACK;
