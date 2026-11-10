DO $$
DECLARE
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_item uuid := '10000000-0000-0000-0000-000000000001';
  v_service uuid := '10000000-0000-0000-0000-000000000002';
  v_employee uuid := '70000000-0000-0000-0000-000000000001';
  v_other_employee uuid := '70000000-0000-0000-0000-000000000002';
  v_unit uuid := '80000000-0000-0000-0000-000000000001';
  v_box uuid := '80000000-0000-0000-0000-000000000002';
  v_when timestamptz := '2026-11-10T20:00:00Z';
  v_first uuid := '60000000-0000-0000-0000-000000000001';
  v_second uuid := '60000000-0000-0000-0000-000000000002';
  v_lines jsonb;
  v_response jsonb;
BEGIN
  PERFORM item_core_internal.post_movement(
    'staff-test-opening',v_tenant,v_item,'opening',50,
    'test','initial','opening-staff',3,NULL,NULL,
    auth.uid(),v_when
  );
  v_lines:=jsonb_build_array(jsonb_build_object(
    'line_id','61000000-0000-0000-0000-000000000001',
    'item_id',v_item,'unit_id',v_box,'quantity',2
  ));

  v_response:=public.app_post_staff_item_consumption_v2(
    v_tenant,v_first,'staff-operation-1',v_employee,v_when,
    v_lines,'Consumo interno'
  );
  IF (v_response->>'total_amount')::numeric<>72
     OR v_response->>'replayed'<>'false'
     OR (SELECT quantity_on_hand FROM public.item_stock
         WHERE item_id=v_item)<>26
     OR (SELECT inventory_quantity
         FROM public.employee_raw_material_consumption_lines
         WHERE consumption_id=v_first)<>24
     OR NOT EXISTS(
       SELECT 1 FROM public.item_ledger_entries
       WHERE source_type='staff_consumption' AND source_id=v_first::text
         AND quantity_delta=-24 AND unit_cost_base=3
     ) THEN
    RAISE EXCEPTION 'staff_consumption_post_failed';
  END IF;

  v_response:=public.app_post_staff_item_consumption_v2(
    v_tenant,v_first,'staff-operation-1',v_employee,v_when,
    v_lines,'Consumo interno'
  );
  IF v_response->>'replayed'<>'true' OR
     (SELECT count(*) FROM public.item_ledger_entries)<>2 THEN
    RAISE EXCEPTION 'staff_consumption_replay_duplicate';
  END IF;

  BEGIN
    PERFORM public.app_post_staff_item_consumption_v2(
      v_tenant,v_first,'staff-operation-1',v_employee,v_when,
      jsonb_set(v_lines,'{0,quantity}','3'::jsonb),'Consumo interno'
    );
    RAISE EXCEPTION 'modified_staff_replay_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'staff_consumption_idempotency_mismatch' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.app_post_staff_item_consumption_v2(
      v_tenant,'60000000-0000-0000-0000-000000000003',
      'staff-wrong-employee',v_other_employee,v_when,v_lines
    );
    RAISE EXCEPTION 'cross_tenant_employee_not_rejected';
  EXCEPTION WHEN foreign_key_violation THEN
    IF SQLERRM<>'invalid_staff_consumption_employee' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.app_post_staff_item_consumption_v2(
      v_tenant,'60000000-0000-0000-0000-000000000004',
      'staff-service',v_employee,v_when,
      jsonb_build_array(jsonb_build_object(
        'line_id','61000000-0000-0000-0000-000000000004',
        'item_id',v_service,'unit_id',v_unit,'quantity',1
      ))
    );
    RAISE EXCEPTION 'service_as_material_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'staff_consumption_item_not_raw_material' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM set_config('app.can_write_staff','false',true);
    PERFORM public.app_post_staff_item_consumption_v2(
      v_tenant,'60000000-0000-0000-0000-000000000005',
      'staff-no-permission',v_employee,v_when,v_lines
    );
    RAISE EXCEPTION 'staff_permission_not_enforced';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM<>'staff_permission_denied' THEN RAISE; END IF;
  END;
  PERFORM set_config('app.can_write_staff','true',true);

  v_response:=public.app_void_staff_item_consumption_v2(
    v_tenant,v_first,'staff-void-1',v_when+interval '1 minute'
  );
  IF v_response->>'replayed'<>'false'
     OR (SELECT quantity_on_hand FROM public.item_stock
         WHERE item_id=v_item)<>50
     OR (SELECT total_amount FROM public.employee_raw_material_consumptions
         WHERE id=v_first)<>72
     OR (SELECT status FROM public.employee_raw_material_consumptions
         WHERE id=v_first)<>'voided'
     OR NOT EXISTS(
       SELECT 1 FROM public.item_ledger_entries
       WHERE movement_type='reversal' AND quantity_delta=24
     ) THEN
    RAISE EXCEPTION 'staff_void_did_not_reverse_original';
  END IF;

  v_response:=public.app_void_staff_item_consumption_v2(
    v_tenant,v_first,'staff-void-1',v_when+interval '1 minute'
  );
  IF v_response->>'replayed'<>'true'
     OR (SELECT count(*) FROM public.item_ledger_entries)<>3 THEN
    RAISE EXCEPTION 'staff_void_replay_duplicated';
  END IF;

  BEGIN
    PERFORM public.app_void_staff_item_consumption_v2(
      v_tenant,v_first,'staff-void-different',v_when+interval '1 minute'
    );
    RAISE EXCEPTION 'staff_void_changed_replay_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'staff_void_idempotency_mismatch' THEN RAISE; END IF;
  END;

  v_response:=public.app_post_staff_item_consumption_v2(
    v_tenant,v_second,'staff-operation-2',v_employee,
    v_when+interval '2 minutes',
    jsonb_build_array(jsonb_build_object(
      'line_id','61000000-0000-0000-0000-000000000002',
      'item_id',v_item,'unit_id',v_unit,'quantity',1
    ))
  );
  UPDATE public.employee_raw_material_consumptions
  SET payroll_run_id='62000000-0000-0000-0000-000000000001'
  WHERE id=v_second;

  BEGIN
    PERFORM public.app_void_staff_item_consumption_v2(
      v_tenant,v_second,'staff-void-payroll',v_when+interval '3 minutes'
    );
    RAISE EXCEPTION 'paid_consumption_void_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM<>'staff_consumption_already_in_payroll' THEN RAISE; END IF;
  END;

  IF (SELECT quantity_on_hand FROM public.item_stock
      WHERE item_id=v_item)<>49
     OR (SELECT count(*) FROM public.item_ledger_entries)<>4
     OR (SELECT COALESCE(sum(quantity_delta),0)
         FROM public.item_ledger_entries WHERE item_id=v_item)<>49
     OR (SELECT count(*) FROM public.employee_raw_material_consumptions)<>2
     OR (SELECT count(*) FROM public.employee_raw_material_consumption_lines)<>2
  THEN RAISE EXCEPTION 'staff_consumption_final_integrity_failed'; END IF;

  RAISE NOTICE 'PASS F2 staff consumption: cost, units, retries, tenant, role, service, void, payroll lock, ledger consistency';
END;
$$;
ROLLBACK;
