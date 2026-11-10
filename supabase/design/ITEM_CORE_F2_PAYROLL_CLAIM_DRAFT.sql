-- KIVO F2: STAFF RAW-MATERIAL PAYROLL CLAIM - DESIGN ONLY.
-- No migration nor deployment. The live app_post_payroll_employee RPC
-- must replace its separate GET TOTAL + MARK PAID calls with this SINGLE
-- atomic claim result during the coordinated F2 payroll cutover.
-- Period boundaries are explicit instants: [start, end_exclusive).
-- The caller must resolve the restaurant's business timezone beforehand.\n-- The final payroll posting RPC MUST bind this window to the run's dates;\n-- this prototype MUST NOT be independently exposed before that gate.
-- Required: F2 staff posted/voided status and employee advisory lock in
-- ITEM_CORE_F2_STAFF_CONSUMPTION_DRAFT.sql.
-- Historical payroll/accounting rows must not be mutated by this prototype.

CREATE OR REPLACE FUNCTION item_core_internal.claim_staff_consumptions_for_payroll(
  p_restaurant_id uuid,
  p_employee_id uuid,
  p_payroll_run_id uuid,
  p_start_at timestamptz,
  p_end_exclusive timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
  v_row public.employee_raw_material_consumptions;
  v_details jsonb := '[]'::jsonb;
  v_total numeric(18,4) := 0;
  v_count integer := 0;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,'planilla.gestionar'
  );
  IF auth.uid() IS NULL OR p_restaurant_id IS NULL
     OR p_employee_id IS NULL OR p_payroll_run_id IS NULL
     OR p_start_at IS NULL OR p_end_exclusive IS NULL
     OR p_start_at >= p_end_exclusive THEN
    RAISE EXCEPTION 'invalid_payroll_claim_window'
      USING ERRCODE='22023';
  END IF;

  -- The same advisory lock is taken by post/void staff operations
  -- BEFORE their row locks. This prevents a phantom consumption from
  -- entering the pay period between the claim's snapshot and update.
  PERFORM pg_advisory_xact_lock(
    hashtext(p_restaurant_id::text),
    hashtext('staff-employee:'||p_employee_id::text)
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.employees e
    WHERE e.id=p_employee_id AND e.restaurant_id=p_restaurant_id
  ) OR NOT EXISTS(
    SELECT 1 FROM public.payroll_runs r
    WHERE r.id=p_payroll_run_id AND r.restaurant_id=p_restaurant_id
      AND r.status='draft'
  ) THEN
    RAISE EXCEPTION 'payroll_claim_employee_or_run_invalid'
      USING ERRCODE='23503';
  END IF;

  -- An existing claim of this period by a DIFFERENT run must not be
  -- silently skipped, as that would understate payroll deductions.
  IF EXISTS(
    SELECT 1 FROM public.employee_raw_material_consumptions c
    WHERE c.restaurant_id=p_restaurant_id
      AND c.employee_id=p_employee_id
      AND c.status='posted'
      AND c.consumed_at>=p_start_at
      AND c.consumed_at<p_end_exclusive
      AND c.payroll_run_id IS NOT NULL
      AND c.payroll_run_id<>p_payroll_run_id
  ) THEN
    RAISE EXCEPTION 'payroll_claim_already_assigned_other_run'
      USING ERRCODE='23514';
  END IF;

  FOR v_row IN
    SELECT c.* FROM public.employee_raw_material_consumptions c
    WHERE c.restaurant_id=p_restaurant_id
      AND c.employee_id=p_employee_id
      AND c.status='posted'
      AND c.consumed_at>=p_start_at
      AND c.consumed_at<p_end_exclusive
      AND (c.payroll_run_id IS NULL OR c.payroll_run_id=p_payroll_run_id)
    ORDER BY c.consumed_at,c.id
    FOR UPDATE
  LOOP
    IF v_row.payroll_run_id IS NULL THEN
      UPDATE public.employee_raw_material_consumptions
      SET payroll_run_id=p_payroll_run_id,updated_at=now()
      WHERE id=v_row.id AND restaurant_id=p_restaurant_id;
    END IF;

    v_details:=v_details||jsonb_build_array(jsonb_build_object(
      'consumption_id',v_row.id,
      'consumed_at',v_row.consumed_at,
      'amount',v_row.total_amount,
      'note',v_row.note
    ));
    v_total:=v_total+v_row.total_amount;
    v_count:=v_count+1;
  END LOOP;

  RETURN jsonb_build_object(
    'payroll_run_id',p_payroll_run_id,
    'employee_id',p_employee_id,
    'total_amount',v_total,
    'consumption_count',v_count,
    'consumptions',v_details,
    'contract_version',2
  );
END;
$$;

REVOKE ALL ON FUNCTION item_core_internal.claim_staff_consumptions_for_payroll(
  uuid,uuid,uuid,timestamptz,timestamptz
) FROM PUBLIC,anon,authenticated;
-- No direct client grant. A vetted payroll posting RPC must call this
-- helper under its own privilege and verified payroll period.

-- Required coordinated follow-up:
-- 1. Update app_post_payroll_employee to call this RPC ONCE and use the
--    returned total/details as both the payroll snapshot and source links.
-- 2. Remove authenticated EXECUTE on old mark RPC or wrap with the same
--    permission/locking contract. Never leave two claim entry points.
-- 3. Update app_get_employee_raw_material_payroll_total to exclude voided
--    rows, or retire it from payroll posting.
-- 4. Update reverse receipt so only the affected run's posted consumptions
--    are unlinked under staff-employee advisory lock.
-- 5. Enforce period timezone conversion using tenant business configuration.
