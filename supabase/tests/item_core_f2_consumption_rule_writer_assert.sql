-- The POS sale fixture opens a transaction. This file always ROLLBACKs.
DO $$
DECLARE
  v_tenant uuid:='00000000-0000-0000-0000-000000000001';
  v_device uuid:='50000000-0000-0000-0000-000000000001';
  v_rule uuid:='40000000-0000-0000-0000-000000000001';
  v_rule_new uuid:='40000000-0000-0000-0000-000000000003';
  v_bag uuid:='30000000-0000-0000-0000-000000000002';
  v_napkin uuid:='30000000-0000-0000-0000-000000000004';
  v_service uuid:='30000000-0000-0000-0000-000000000003';
  v_unit uuid:='10000000-0000-0000-0000-000000000001';
  v_sales_type uuid:='20000000-0000-0000-0000-000000000001';
  v_payload jsonb;
  v_catalog jsonb;
  v_first_snapshot text;
  v_output public.item_consumption_rules;
BEGIN
  v_catalog:=public.pos_pull_item_catalog_v2(
    v_tenant,v_device,'fixture-secret'
  );
  v_first_snapshot:=v_catalog->>'snapshot_id';

  v_payload:=jsonb_build_object(
    'id',v_rule,'source_item_id',NULL,'consumed_item_id',v_bag,
    'sales_type_id',v_sales_type,'scope','per_order','quantity',2,
    'unit_id',v_unit,'priority',10,'is_active',true
  );
  v_output:=public.app_upsert_item_consumption_rule_v2(v_tenant,v_payload);
  IF v_output.quantity<>2
     OR (SELECT revision FROM public.item_catalog_revisions
         WHERE restaurant_id=v_tenant)<>2
     OR (SELECT snapshot_id::text FROM public.item_catalog_revisions
         WHERE restaurant_id=v_tenant)=v_first_snapshot THEN
    RAISE EXCEPTION 'rule_update_did_not_bump_catalog';
  END IF;

  -- Identical retry must not advance revision or change rule payload.
  PERFORM public.app_upsert_item_consumption_rule_v2(v_tenant,v_payload);
  IF (SELECT revision FROM public.item_catalog_revisions
      WHERE restaurant_id=v_tenant)<>2 THEN
    RAISE EXCEPTION 'rule_idempotent_replay_bumped_revision';
  END IF;

  v_payload:=jsonb_build_object(
    'id',v_rule_new,'source_item_id',NULL,
    'consumed_item_id',v_napkin,'sales_type_id',v_sales_type,
    'scope','per_order','quantity',1,'unit_id',v_unit,
    'priority',30,'is_active',true
  );
  v_output:=public.app_upsert_item_consumption_rule_v2(v_tenant,v_payload);
  v_catalog:=public.pos_pull_item_catalog_v2(
    v_tenant,v_device,'fixture-secret'
  );
  IF (v_catalog->>'revision')::bigint<>3
     OR NOT EXISTS(
       SELECT 1 FROM jsonb_array_elements(v_catalog->'consumption_rules') r
       WHERE r->>'id'=v_rule_new::text
         AND r->>'consumed_item_id'=v_napkin::text
     ) THEN
    RAISE EXCEPTION 'rule_create_not_published_atomically';
  END IF;

  BEGIN
    PERFORM public.app_upsert_item_consumption_rule_v2(
      v_tenant,jsonb_set(v_payload,'{consumed_item_id}',
        to_jsonb(v_service::text))
    );
    RAISE EXCEPTION 'service_rule_was_allowed';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'consumption_rule_invalid_target_or_unit'
      THEN RAISE; END IF;
  END;
  IF (SELECT revision FROM public.item_catalog_revisions
      WHERE restaurant_id=v_tenant)<>3 THEN
    RAISE EXCEPTION 'invalid_rule_advanced_catalog';
  END IF;

  PERFORM set_config('app.can_write_rule','false',true);
  BEGIN
    PERFORM public.app_upsert_item_consumption_rule_v2(
      v_tenant,v_payload
    );
    RAISE EXCEPTION 'rule_permission_not_enforced';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM<>'rule_permission_denied' THEN RAISE; END IF;
  END;
  PERFORM set_config('app.can_write_rule','true',true);

  IF has_table_privilege(
       'authenticated','public.item_consumption_rules','UPDATE'
     ) THEN
    RAISE EXCEPTION 'direct_rule_writes_still_allowed';
  END IF;
  IF NOT has_function_privilege(
       'authenticated',
       'public.app_upsert_item_consumption_rule_v2(uuid,jsonb)',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'rule_rpc_missing_client_grant';
  END IF;

  RAISE NOTICE 'PASS F2 rule writer: catalog revision, idempotence, no service, permission, no direct DML';
END;
$$;
ROLLBACK;
