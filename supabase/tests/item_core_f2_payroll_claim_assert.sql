-- Assert payroll claim integration in disposable PostgreSQL; always ROLLBACK.
DO $$
DECLARE
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_employee uuid := '70000000-0000-0000-0000-000000000001';
  v_item uuid := '10000000-0000-0000-0000-000000000001';
  v_unit uuid := '80000000-0000-0000-0000-000000000001';
  v_start timestamptz := '2026-11-01T06:00:00Z';
  v_end timestamptz := '2026-11-16T06:00:00Z';
  v_run uuid := '62000000-0000-0000-0000-000000000001';
  v_other_run uuid := '62000000-0000-0000-0000-000000000002';
  v_posted uuid := '63000000-0000-0000-0000-000000000001';
  v_voided uuid := '63000000-0000-0000-0000-000000000002';
  v_outside uuid := '63000000-0000-0000-0000-000000000003';
  v_response jsonb;
  v_details jsonb;
BEGIN
  PERFORM item_core_internal.post_movement(
    'payroll-fixture-opening',v_tenant,v_item,'opening',100,
    'test','initial','payroll-opening',3,NULL,NULL,auth.uid(),v_start
  );

  PERFORM public.app_post_staff_item_consumption_v2(
    v_tenant,v_posted,'payroll-staff-post',v_employee,
    '2026-11-10T12:00:00Z',
    jsonb_build_array(jsonb_build_object(
      'line_id','64000000-0000-0000-0000-000000000001',
      'item_id',v_item,'unit_id',v_unit,'quantity',2
    ))
  );
  PERFORM public.app_post_staff_item_consumption_v2(
    v_tenant,v_voided,'payroll-staff-voidable',v_employee,
    '2026-11-11T12:00:00Z',
    jsonb_build_array(jsonb_build_object(
      'line_id','64000000-0000-0000-0000-000000000002',
      'item_id',v_item,'unit_id',v_unit,'quantity',4
    ))
  );
  PERFORM public.app_void_staff_item_consumption_v2(
    v_tenant,v_voided,'payroll-void-key','2026-11-12T12:00:00Z'
  );

  PERFORM public.app_post_staff_item_consumption_v2(
    v_tenant,v_outside,'payroll-staff-outside',v_employee,
    '2026-11-16T06:00:00Z',
    jsonb_build_array(jsonb_build_object(
      'line_id','64000000-0000-0000-0000-000000000003',
      'item_id',v_item,'unit_id',v_unit,'quantity',5
    ))
  );

  v_response:=item_core_internal.claim_staff_consumptions_for_payroll(
    v_tenant,v_employee,v_run,v_start,v_end
  );
  IF (v_response->>'total_amount')::numeric<>6
     OR (v_response->>'consumption_count')::integer<>1
     OR (SELECT payroll_run_id
         FROM public.employee_raw_material_consumptions
         WHERE id=v_posted)<>v_run
     OR (SELECT payroll_run_id
         FROM public.employee_raw_material_consumptions
         WHERE id=v_voided) IS NOT NULL
     OR (SELECT payroll_run_id
         FROM public.employee_raw_material_consumptions
         WHERE id=v_outside) IS NOT NULL
  THEN RAISE EXCEPTION 'payroll_claim_wrong_amount_or_window'; END IF;

  -- Calling again must return the same claim rather than subtracting twice.
  v_response:=item_core_internal.claim_staff_consumptions_for_payroll(
    v_tenant,v_employee,v_run,v_start,v_end
  );
  v_details:=v_response->'consumptions';
  IF (v_response->>'total_amount')::numeric<>6
     OR jsonb_array_length(v_details)<>1
     OR (v_details->0->>'consumption_id')::uuid<>v_posted THEN
    RAISE EXCEPTION 'payroll_claim_replay_inconsistent';
  END IF;

  -- No second payroll run can silently claim a posted consumption.
  BEGIN
    PERFORM item_core_internal.claim_staff_consumptions_for_payroll(
      v_tenant,v_employee,v_other_run,v_start,v_end
    );
    RAISE EXCEPTION 'second_payroll_run_claim_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'payroll_claim_already_assigned_other_run' THEN RAISE; END IF;
  END;

  -- An employee whose consumption was claimed cannot void it.
  BEGIN
    PERFORM public.app_void_staff_item_consumption_v2(
      v_tenant,v_posted,'cannot-void-claimed','2026-11-13T00:00:00Z'
    );
    RAISE EXCEPTION 'claimed_consumption_void_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'staff_consumption_already_in_payroll' THEN RAISE; END IF;
  END;

  -- Payroll authorisation must not be inferred from staff rights.
  BEGIN
    PERFORM set_config('app.can_write_payroll','false',true);
    PERFORM item_core_internal.claim_staff_consumptions_for_payroll(
      v_tenant,v_employee,v_run,v_start,v_end
    );
    RAISE EXCEPTION 'payroll_permission_not_enforced';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM<>'fixture_permission_denied' THEN RAISE; END IF;
  END;
  PERFORM set_config('app.can_write_payroll','true',true);

  BEGIN
    PERFORM item_core_internal.claim_staff_consumptions_for_payroll(
      v_tenant,v_employee,
      '62000000-0000-0000-0000-000000000003',v_start,v_end
    );
    RAISE EXCEPTION 'other_tenant_payroll_run_not_rejected';
  EXCEPTION WHEN foreign_key_violation THEN
    IF SQLERRM<>'payroll_claim_employee_or_run_invalid' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM item_core_internal.claim_staff_consumptions_for_payroll(
      v_tenant,v_employee,v_run,v_end,v_start
    );
    RAISE EXCEPTION 'invalid_payroll_period_not_rejected';
  EXCEPTION WHEN invalid_parameter_value THEN
    IF SQLERRM<>'invalid_payroll_claim_window' THEN RAISE; END IF;
  END;

  -- A settled run line blocks backdated entries, even when the UTC
  -- timestamp has already crossed midnight but Managua is still Nov 15.
  INSERT INTO public.payroll_run_lines VALUES(
    '65000000-0000-0000-0000-000000000001',v_run,v_employee
  );
  BEGIN
    PERFORM public.app_post_staff_item_consumption_v2(
      v_tenant,'63000000-0000-0000-0000-000000000004',
      'backdated-after-payroll',v_employee,
      '2026-11-16T05:59:00Z',
      jsonb_build_array(jsonb_build_object(
        'line_id','64000000-0000-0000-0000-000000000004',
        'item_id',v_item,'unit_id',v_unit,'quantity',1
      ))
    );
    RAISE EXCEPTION 'backdated_payroll_period_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'staff_consumption_payroll_period_closed' THEN RAISE; END IF;
  END;

  -- Exact previously posted command remains safe to replay, even after
  -- the period is closed: it is a no-op and does not change payroll.
  v_response:=public.app_post_staff_item_consumption_v2(
    v_tenant,v_posted,'payroll-staff-post',v_employee,
    '2026-11-10T12:00:00Z',
    jsonb_build_array(jsonb_build_object(
      'line_id','64000000-0000-0000-0000-000000000001',
      'item_id',v_item,'unit_id',v_unit,'quantity',2
    ))
  );
  IF v_response->>'replayed'<>'true' THEN
    RAISE EXCEPTION 'closed_period_replay_not_idempotent';
  END IF;

  -- Claims must never be initiated or modified after a payroll run closes.
  UPDATE public.payroll_runs SET status='posted' WHERE id=v_run;
  BEGIN
    PERFORM item_core_internal.claim_staff_consumptions_for_payroll(
      v_tenant,v_employee,v_run,v_start,v_end
    );
    RAISE EXCEPTION 'posted_payroll_run_claim_not_rejected';
  EXCEPTION WHEN foreign_key_violation THEN
    IF SQLERRM<>'payroll_claim_employee_or_run_invalid' THEN RAISE; END IF;
  END;

  -- A normal client role must not be able to execute the internal claim.
  IF has_function_privilege('authenticated',
       'item_core_internal.claim_staff_consumptions_for_payroll(uuid,uuid,uuid,timestamptz,timestamptz)',
       'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated_can_call_private_payroll_claim';
  END IF;

  -- Only append-only ledger events for posted + voided + outside remain.
  IF (SELECT count(*) FROM public.item_ledger_entries)<>5
     OR (SELECT quantity_on_hand FROM public.item_stock
         WHERE item_id=v_item)<>93
     OR (SELECT COALESCE(sum(quantity_delta),0)
         FROM public.item_ledger_entries WHERE item_id=v_item)<>93 THEN
    RAISE EXCEPTION 'payroll_claim_modified_inventory_ledger';
  END IF;
  RAISE NOTICE 'PASS F2 payroll claim: void exclusion, half-open period, replay, overlap, permission, tenant, inventory consistency';
END;
$$;
ROLLBACK;
