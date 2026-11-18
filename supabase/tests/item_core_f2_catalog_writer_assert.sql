-- Transaction begins in the shared isolated POS fixture; always ROLLBACK.
DO $$
DECLARE
  v_tenant uuid:='00000000-0000-0000-0000-000000000001';
  v_item_id uuid:='30000000-0000-0000-0000-000000000001';
  v_device uuid:='50000000-0000-0000-0000-000000000001';
  v_first jsonb;
  v_second jsonb;
  v_result public.items;
BEGIN
  v_first:=public.pos_pull_item_catalog_v2(
    v_tenant,v_device,'fixture-secret'
  );
  v_result:=public.app_upsert_item_v2(
    v_tenant,jsonb_build_object('id',v_item_id,'name','Botella actualizada')
  );
  v_second:=public.pos_pull_item_catalog_v2(
    v_tenant,v_device,'fixture-secret'
  );
  IF v_result.name<>'Botella actualizada'
     OR (v_second->>'revision')::bigint<>2
     OR v_second->>'snapshot_id'=v_first->>'snapshot_id'
     OR NOT EXISTS(
       SELECT 1 FROM jsonb_array_elements(v_second->'items') i
       WHERE i->>'id'=v_item_id::text
         AND i->>'name'='Botella actualizada'
     ) THEN
    RAISE EXCEPTION 'item_write_catalog_revision_not_atomic';
  END IF;

  -- Failed master modification must not advance revision.
  BEGIN
    PERFORM public.app_upsert_item_v2(
      v_tenant,jsonb_build_object('id',v_item_id,'name','FORCE_ERROR')
    );
    RAISE EXCEPTION 'expected_master_error';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'fixture_upsert_failed' THEN RAISE; END IF;
  END;
  IF (SELECT revision FROM public.item_catalog_revisions
      WHERE restaurant_id=v_tenant)<>2
     OR (SELECT name FROM public.items WHERE id=v_item_id)
       <>'Botella actualizada' THEN
    RAISE EXCEPTION 'failed_upsert_changed_catalog_revision';
  END IF;

  -- Bridge must reject operators without item permission.
  PERFORM set_config('app.can_write_inventory','false',true);
  BEGIN
    PERFORM public.app_upsert_item_v2(
      v_tenant,jsonb_build_object('id',v_item_id,'name','Unauthorized')
    );
    RAISE EXCEPTION 'missing_permission_rejection';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM<>'item_write_not_authorized' THEN RAISE; END IF;
  END;
  PERFORM set_config('app.can_write_inventory','true',true);

  -- Only one client write path may survive cutover.
  IF has_function_privilege(
    'authenticated','public.app_upsert_item(uuid,jsonb)','EXECUTE'
  ) THEN
    RAISE EXCEPTION 'old_upsert_still_executable_by_clients';
  END IF;
  IF NOT has_function_privilege(
    'authenticated','public.app_upsert_item_v2(uuid,jsonb)','EXECUTE'
  ) THEN
    RAISE EXCEPTION 'new_upsert_unavailable';
  END IF;

  RAISE NOTICE 'PASS F2 item writer: revision lock, atomic publish, rollback, role, single API';
END;
$$;
ROLLBACK;
