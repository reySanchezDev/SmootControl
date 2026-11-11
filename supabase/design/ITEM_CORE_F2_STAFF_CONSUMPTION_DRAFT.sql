-- KIVO F2 - EMPLOYEE RAW MATERIAL CONSUMPTION - DRAFT ONLY.
-- NOT A MIGRATION. Do not execute against primary local or production DB.
-- Required cutover: employee_raw_material_consumption_lines.product_id
-- (FK to public.products) must be replaced by item_id (tenant-consistent
-- FK to items), without attempting to keep the old NOT NULL column active.
-- Historical laboratory data may be discarded by separate approved cutover.
-- This prototype never DELETEs posted ledger entries. Correction = reversal.
-- Existing payroll reads/marking RPCs MUST filter status='posted' and keep
-- payroll snapshots; those changes are a separate required cutover contract.

ALTER TABLE public.employee_raw_material_consumptions
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'posted'
    CHECK (status IN ('posted','voided')),
  ADD COLUMN IF NOT EXISTS operation_key text,
  ADD COLUMN IF NOT EXISTS operation_digest text,
  ADD COLUMN IF NOT EXISTS void_operation_key text,
  ADD COLUMN IF NOT EXISTS void_digest text,
  ADD COLUMN IF NOT EXISTS voided_at timestamptz,
  ADD COLUMN IF NOT EXISTS voided_by_user_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS staff_consumption_operation_uq
  ON public.employee_raw_material_consumptions
  (restaurant_id,operation_key)
  WHERE operation_key IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS staff_consumption_void_operation_uq
  ON public.employee_raw_material_consumptions
  (restaurant_id,void_operation_key)
  WHERE void_operation_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public.app_post_staff_item_consumption_v2(
  p_restaurant_id uuid,
  p_consumption_id uuid,
  p_operation_key text,
  p_employee_id uuid,
  p_consumed_at timestamptz,
  p_lines jsonb,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_digest text;
  v_existing public.employee_raw_material_consumptions;
  v_line jsonb;
  v_item public.items;
  v_unit public.item_units;
  v_unit_name text;
  v_unit_code text;
  v_classification_id uuid;
  v_line_id uuid;
  v_item_id uuid;
  v_unit_id uuid;
  v_qty numeric;
  v_qty_base numeric;
  v_price_base numeric;
  v_total numeric := 0;
  v_count integer := 0;
  v_business_timezone text;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,'personal.consumos_materia.registrar'
  );
  IF v_actor IS NULL OR p_consumption_id IS NULL
     OR p_employee_id IS NULL OR p_consumed_at IS NULL
     OR p_operation_key IS NULL OR btrim(p_operation_key)=''
     OR p_lines IS NULL OR jsonb_typeof(p_lines)<>'array'
     OR jsonb_array_length(p_lines)=0 THEN
    RAISE EXCEPTION 'invalid_staff_item_consumption'
      USING ERRCODE='22023';
  END IF;
  -- Synchronize new staff consumption with payroll period claims.
  PERFORM pg_advisory_xact_lock(
    hashtext(p_restaurant_id::text),
    hashtext('staff-employee:'||p_employee_id::text)
  );
  IF NOT EXISTS(
    SELECT 1 FROM public.employees e
    WHERE e.id=p_employee_id AND e.restaurant_id=p_restaurant_id
      AND e.is_active
  ) THEN
    RAISE EXCEPTION 'invalid_staff_consumption_employee'
      USING ERRCODE='23503';
  END IF;

  v_digest:=md5(jsonb_build_object(
    'restaurant',p_restaurant_id,'id',p_consumption_id,
    'operation',p_operation_key,'employee',p_employee_id,
    'consumed_at',p_consumed_at,'lines',p_lines,
    'note',p_note
  )::text);

  PERFORM pg_advisory_xact_lock(
    hashtext(p_restaurant_id::text),hashtext('staff:'||p_operation_key)
  );

  SELECT * INTO v_existing
  FROM public.employee_raw_material_consumptions
  WHERE restaurant_id=p_restaurant_id AND operation_key=p_operation_key
  FOR UPDATE;
  IF v_existing.id IS NOT NULL THEN
    IF v_existing.id<>p_consumption_id
       OR v_existing.operation_digest<>v_digest THEN
      RAISE EXCEPTION 'staff_consumption_idempotency_mismatch'
        USING ERRCODE='23514';
    END IF;
    RETURN jsonb_build_object(
      'consumption_id',v_existing.id,'total_amount',v_existing.total_amount,
      'status',v_existing.status,'replayed',true,'contract_version',2
    );
  END IF;
  IF EXISTS(
    SELECT 1 FROM public.employee_raw_material_consumptions
    WHERE id=p_consumption_id
  ) THEN
    RAISE EXCEPTION 'staff_consumption_id_collision'
      USING ERRCODE='23505';
  END IF;

  -- A late/backdated consumption must not change an employee's already
  -- established payroll period. The business date is resolved from a
  -- server-owned IANA timezone, NEVER from a caller/session timezone.
  SELECT b.text_value INTO v_business_timezone
  FROM public.business_rules b
  WHERE b.restaurant_id=p_restaurant_id
    AND b.key='business_timezone';
  IF v_business_timezone IS NULL OR NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_timezone_names tz
    WHERE tz.name=v_business_timezone
  ) THEN
    RAISE EXCEPTION 'staff_business_timezone_unconfigured'
      USING ERRCODE='23514';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.payroll_run_lines pl
    JOIN public.payroll_runs pr ON pr.id=pl.payroll_run_id
    WHERE pr.restaurant_id=p_restaurant_id
      AND pl.employee_id=p_employee_id
      AND pr.status IN ('draft','posted')
      AND (p_consumed_at AT TIME ZONE v_business_timezone)::date
          BETWEEN pr.period_start AND pr.period_end
  ) THEN
    RAISE EXCEPTION 'staff_consumption_payroll_period_closed'
      USING ERRCODE='23514';
  END IF;

  IF EXISTS(
    SELECT 1 FROM jsonb_array_elements(p_lines) l
    GROUP BY (l->>'item_id')::uuid HAVING count(*)>1
  ) OR EXISTS(
    SELECT 1 FROM jsonb_array_elements(p_lines) l
    GROUP BY (l->>'line_id')::uuid HAVING count(*)>1
  ) THEN
    RAISE EXCEPTION 'duplicate_staff_consumption_item_or_line'
      USING ERRCODE='23514';
  END IF;

  SELECT id INTO v_classification_id
  FROM public.item_classifications
  WHERE restaurant_id=p_restaurant_id
    AND code='raw_material' AND is_active;
  IF v_classification_id IS NULL THEN
    RAISE EXCEPTION 'raw_material_classification_missing'
      USING ERRCODE='23514';
  END IF;

  INSERT INTO public.employee_raw_material_consumptions(
    id,restaurant_id,employee_id,consumed_at,note,total_amount,
    payroll_run_id,created_by_user_id,operation_key,operation_digest,status
  ) VALUES(
    p_consumption_id,p_restaurant_id,p_employee_id,p_consumed_at,p_note,0,
    NULL,v_actor,p_operation_key,v_digest,'posted'
  );

  FOR v_line IN
    SELECT value FROM jsonb_array_elements(p_lines)
    ORDER BY (value->>'item_id')::uuid
  LOOP
    IF jsonb_typeof(v_line)<>'object' THEN
      RAISE EXCEPTION 'invalid_staff_consumption_line'
        USING ERRCODE='22023';
    END IF;
    v_line_id:=nullif(v_line->>'line_id','')::uuid;
    v_item_id:=nullif(v_line->>'item_id','')::uuid;
    v_unit_id:=nullif(v_line->>'unit_id','')::uuid;
    v_qty:=nullif(v_line->>'quantity','')::numeric;
    IF v_line_id IS NULL OR v_item_id IS NULL OR v_unit_id IS NULL
       OR v_qty IS NULL OR v_qty<=0 THEN
      RAISE EXCEPTION 'invalid_staff_consumption_quantity'
        USING ERRCODE='22023';
    END IF;

    SELECT * INTO v_item FROM public.items
    WHERE id=v_item_id AND restaurant_id=p_restaurant_id
      AND item_type='inventory' AND is_active
    FOR SHARE;
    IF v_item.id IS NULL OR NOT EXISTS(
      SELECT 1 FROM public.item_classification_links l
      WHERE l.restaurant_id=p_restaurant_id AND l.item_id=v_item_id
        AND l.classification_id=v_classification_id
    ) THEN
      RAISE EXCEPTION 'staff_consumption_item_not_raw_material'
        USING ERRCODE='23514';
    END IF;

    SELECT * INTO v_unit FROM public.item_units
    WHERE restaurant_id=p_restaurant_id
      AND item_id=v_item_id AND unit_id=v_unit_id AND is_active
    FOR SHARE;
    IF v_unit.item_id IS NULL OR v_unit.quantity_in_base<=0 THEN
      RAISE EXCEPTION 'staff_consumption_unit_invalid'
        USING ERRCODE='23514';
    END IF;
    SELECT name,code INTO v_unit_name,v_unit_code
    FROM public.measurement_units
    WHERE id=v_unit_id AND is_active
      AND (restaurant_id IS NULL OR restaurant_id=p_restaurant_id);
    IF v_unit_name IS NULL OR v_unit_code IS NULL THEN
      RAISE EXCEPTION 'staff_consumption_measurement_unit_invalid'
        USING ERRCODE='23514';
    END IF;
    v_qty_base:=v_qty*v_unit.quantity_in_base;
    IF round(v_qty_base,6)<>v_qty_base THEN
      RAISE EXCEPTION 'staff_consumption_precision_loss'
        USING ERRCODE='23514';
    END IF;
    v_price_base:=v_item.base_unit_cost;

    INSERT INTO public.employee_raw_material_consumption_lines(
      id,consumption_id,item_id,product_name,quantity,inventory_quantity,
      unit_id,unit_name,unit_code,unit_price,subtotal
    ) VALUES(
      v_line_id,p_consumption_id,v_item_id,v_item.name,v_qty,v_qty_base,
      v_unit_id,v_unit_name,v_unit_code,
      v_price_base*v_unit.quantity_in_base,
      round(v_qty_base*v_price_base,4)
    );

    PERFORM item_core_internal.post_movement(
      'staff:'||p_consumption_id::text||':line:'||v_line_id::text,
      p_restaurant_id,v_item_id,'staff_consumption',-v_qty_base,
      'staff_consumption',p_consumption_id::text,
      'staff:'||p_operation_key||':line:'||v_line_id::text,
      v_price_base,NULL,NULL,v_actor,p_consumed_at
    );

    v_total:=v_total+round(v_qty_base*v_price_base,4);
    v_count:=v_count+1;
  END LOOP;

  UPDATE public.employee_raw_material_consumptions
  SET total_amount=v_total, updated_at=now()
  WHERE id=p_consumption_id AND restaurant_id=p_restaurant_id;

  RETURN jsonb_build_object(
    'consumption_id',p_consumption_id,'total_amount',v_total,
    'status','posted','line_count',v_count,'replayed',false,
    'contract_version',2
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_void_staff_item_consumption_v2(
  p_restaurant_id uuid,
  p_consumption_id uuid,
  p_void_operation_key text,
  p_voided_at timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_header public.employee_raw_material_consumptions;
  v_m public.item_ledger_entries;
  v_digest text;
  v_count integer:=0;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,'personal.consumos_materia.registrar'
  );
  IF v_actor IS NULL OR p_consumption_id IS NULL
     OR p_void_operation_key IS NULL OR btrim(p_void_operation_key)=''
     OR p_voided_at IS NULL THEN
    RAISE EXCEPTION 'invalid_staff_consumption_void'
      USING ERRCODE='22023';
  END IF;
  v_digest:=md5(jsonb_build_object(
    'restaurant',p_restaurant_id,'consumption',p_consumption_id,
    'operation',p_void_operation_key,'voided_at',p_voided_at
  )::text);

  -- Advisory lock comes BEFORE row lock, matching the ordering in
  -- payroll claim and post: no void can race a payroll association.
  SELECT * INTO v_header
  FROM public.employee_raw_material_consumptions
  WHERE id=p_consumption_id AND restaurant_id=p_restaurant_id;
  IF v_header.id IS NULL THEN
    RAISE EXCEPTION 'staff_consumption_not_found'
      USING ERRCODE='23503';
  END IF;
  PERFORM pg_advisory_xact_lock(
    hashtext(p_restaurant_id::text),
    hashtext('staff-employee:'||v_header.employee_id::text)
  );
  SELECT * INTO v_header
  FROM public.employee_raw_material_consumptions
  WHERE id=p_consumption_id AND restaurant_id=p_restaurant_id
  FOR UPDATE;
  IF v_header.id IS NULL THEN
    RAISE EXCEPTION 'staff_consumption_not_found'
      USING ERRCODE='23503';
  END IF;
  IF v_header.status='voided' THEN
    IF v_header.void_operation_key<>p_void_operation_key
       OR v_header.void_digest<>v_digest THEN
      RAISE EXCEPTION 'staff_void_idempotency_mismatch'
        USING ERRCODE='23514';
    END IF;
    RETURN jsonb_build_object(
      'consumption_id',p_consumption_id,'status','voided',
      'replayed',true,'contract_version',2
    );
  END IF;
  IF v_header.payroll_run_id IS NOT NULL THEN
    RAISE EXCEPTION 'staff_consumption_already_in_payroll'
      USING ERRCODE='23514';
  END IF;

  FOR v_m IN
    SELECT * FROM public.item_ledger_entries
    WHERE restaurant_id=p_restaurant_id
      AND source_type='staff_consumption'
      AND source_id=p_consumption_id::text
      AND movement_type='staff_consumption'
    ORDER BY item_id,id
  LOOP
    PERFORM item_core_internal.post_movement(
      'staff-void:'||p_consumption_id::text||':movement:'||v_m.id,
      p_restaurant_id,v_m.item_id,'reversal',-v_m.quantity_delta,
      'staff_consumption_void',p_consumption_id::text,
      'staff-void:'||p_void_operation_key||':movement:'||v_m.id,
      v_m.unit_cost_base,v_m.id,NULL,v_actor,p_voided_at
    );
    v_count:=v_count+1;
  END LOOP;

  IF v_count=0 THEN
    RAISE EXCEPTION 'staff_consumption_missing_original_movements'
      USING ERRCODE='23514';
  END IF;

  UPDATE public.employee_raw_material_consumptions
  SET status='voided',void_operation_key=p_void_operation_key,
      void_digest=v_digest,voided_at=p_voided_at,
      voided_by_user_id=v_actor,updated_at=now()
  WHERE id=p_consumption_id AND restaurant_id=p_restaurant_id;

  RETURN jsonb_build_object(
    'consumption_id',p_consumption_id,'status','voided',
    'reversed_movements',v_count,'replayed',false,'contract_version',2
  );
END;
$$;

REVOKE ALL ON FUNCTION public.app_post_staff_item_consumption_v2(
  uuid,uuid,text,uuid,timestamptz,jsonb,text
),public.app_void_staff_item_consumption_v2(uuid,uuid,text,timestamptz)
FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_post_staff_item_consumption_v2(
  uuid,uuid,text,uuid,timestamptz,jsonb,text
),public.app_void_staff_item_consumption_v2(uuid,uuid,text,timestamptz)
TO authenticated;

-- Future F2 migration: payroll totals must only sum status='posted',
-- and paid-run marking must lock headers and reject voided rows. Existing
-- payroll functions MUST be updated atomically with this contract.
