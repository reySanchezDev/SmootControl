-- Runs after F2 POS fixture, catalog fixture and catalog pull draft.
-- Transaction opened by POS fixture. All work must be rolled back.
INSERT INTO public.item_catalog_revisions(restaurant_id)
VALUES('00000000-0000-0000-0000-000000000001');

-- Classification is part of the full snapshot, not POS visibility.
INSERT INTO public.item_classifications(
  id,restaurant_id,code,name,is_active
) VALUES(
  '90000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'PACKAGING','Packaging',true
);
INSERT INTO public.item_classification_links(
  restaurant_id,item_id,classification_id
) VALUES(
  '00000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000002',
  '90000000-0000-0000-0000-000000000001'
);

DO $
DECLARE
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_device uuid := '50000000-0000-0000-0000-000000000001';
  v_item uuid := '30000000-0000-0000-0000-000000000001';
  v_first jsonb;
  v_repeated jsonb;
  v_second jsonb;
BEGIN
  v_first:=public.pos_pull_item_catalog_v2(
    v_tenant,v_device,'fixture-secret'
  );
  IF (v_first->>'contract_version')::int<>2
     OR (v_first->>'revision')::bigint<>1
     OR (v_first->>'snapshot_complete')::boolean<>true
     OR jsonb_array_length(v_first->'items')<>4
     OR jsonb_array_length(v_first->'item_units')<>4
     OR jsonb_array_length(v_first->'item_classifications')<>1
     OR jsonb_array_length(v_first->'item_classification_links')<>1
     OR jsonb_array_length(v_first->'consumption_rules')<>2
     OR NOT EXISTS(
       SELECT 1 FROM jsonb_array_elements(v_first->'items') i
       WHERE i->>'code'='NAP-1'
         AND i->>'item_type'='non_inventory'
         AND i->>'visible_in_pos'='false'
     ) THEN
    RAISE EXCEPTION 'catalog_complete_snapshot_invalid';
  END IF;

  -- Same revision must produce the same snapshot identifier and payload.
  v_repeated:=public.pos_pull_item_catalog_v2(
    v_tenant,v_device,'fixture-secret'
  );
  IF v_first<>v_repeated THEN
    RAISE EXCEPTION 'catalog_replay_not_identical';
  END IF;

  -- A trusted catalog modification must replace the revision and ID.
  PERFORM item_core_internal.bump_item_catalog_revision(v_tenant);
  v_second:=public.pos_pull_item_catalog_v2(
    v_tenant,v_device,'fixture-secret'
  );
  IF (v_second->>'revision')::bigint<>2
     OR v_second->>'snapshot_id'=v_first->>'snapshot_id' THEN
    RAISE EXCEPTION 'catalog_revision_not_advanced';
  END IF;

  BEGIN
    PERFORM public.pos_pull_item_catalog_v2(
      v_tenant,v_device,'wrong-secret'
    );
    RAISE EXCEPTION 'catalog_device_secret_not_enforced';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM<>'invalid_device_credentials' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.pos_pull_item_catalog_v2(
      '00000000-0000-0000-0000-000000000002',
      v_device,'fixture-secret'
    );
    RAISE EXCEPTION 'catalog_cross_tenant_device_not_rejected';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM<>'invalid_device_credentials' THEN RAISE; END IF;
  END;

  -- Missing canonical base unit must abort the entire response.
  UPDATE public.item_units SET is_active=false
  WHERE restaurant_id=v_tenant AND item_id=v_item;
  BEGIN
    PERFORM public.pos_pull_item_catalog_v2(
      v_tenant,v_device,'fixture-secret'
    );
    RAISE EXCEPTION 'incomplete_catalog_was_returned';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'catalog_missing_base_unit' THEN RAISE; END IF;
  END;
  UPDATE public.item_units SET is_active=true
  WHERE restaurant_id=v_tenant AND item_id=v_item;

  -- A linked inactive classification invalidates the whole snapshot.
  UPDATE public.item_classifications SET is_active=false
  WHERE restaurant_id=v_tenant
    AND id='90000000-0000-0000-0000-000000000001'::uuid;
  BEGIN
    PERFORM public.pos_pull_item_catalog_v2(
      v_tenant,v_device,'fixture-secret'
    );
    RAISE EXCEPTION 'invalid_classification_link_exported';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'catalog_invalid_classification_link' THEN RAISE; END IF;
  END;
  UPDATE public.item_classifications SET is_active=true
  WHERE restaurant_id=v_tenant
    AND id='90000000-0000-0000-0000-000000000001'::uuid;

  -- No runtime client has direct write permissions on revisions.
  IF has_table_privilege('authenticated',
       'public.item_catalog_revisions','UPDATE')
     OR has_function_privilege('authenticated',
       'item_core_internal.bump_item_catalog_revision(uuid)',
       'EXECUTE') THEN
    RAISE EXCEPTION 'catalog_revision_writable_by_client';
  END IF;

  RAISE NOTICE 'PASS F2 catalog export: complete/tenant/revision/replay/unit/security';
END;
$$;
ROLLBACK;
