CREATE OR REPLACE FUNCTION public.app_post_payroll_employee(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  employee_id_value uuid := (p_payload ->> 'employee_id')::uuid;
  period_start_value date := (p_payload ->> 'period_start')::date;
  period_end_value date := (p_payload ->> 'period_end')::date;
  base_salary_value numeric := COALESCE((p_payload ->> 'base_salary')::numeric, 0);
  requested_advance_deduction numeric :=
    COALESCE((p_payload ->> 'salary_advance_deduction')::numeric, 0);
  payment_amount_value numeric :=
    COALESCE((p_payload ->> 'payment_amount')::numeric, 0);
  payroll_run_id_value uuid;
  line_id_value uuid;
  receipt_id_value uuid;
  period_label_value text;
  pos_consumption_value numeric := 0;
  raw_consumption_value numeric := 0;
  total_consumption_value numeric := 0;
  overtime_value numeric := 0;
  net_pay_value numeric;
  balance_amount_value numeric;
  paid_amount_after_value numeric;
  balance_after_value numeric;
  advance_balance_after_value numeric;
  remaining_deduction numeric;
  advance_row record;
  deduction_for_row numeric;
  existing_line record;
  consumption_details jsonb := '[]'::jsonb;
  raw_details jsonb := '[]'::jsonb;
  advance_details jsonb := '[]'::jsonb;
  overtime_details jsonb := '[]'::jsonb;
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'planilla.gestionar');
  IF payment_amount_value <= 0 THEN
    RAISE EXCEPTION 'Monto de pago invalido';
  END IF;
  IF period_end_value < period_start_value THEN
    RAISE EXCEPTION 'Periodo de planilla invalido';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.employees WHERE id = employee_id_value
      AND restaurant_id = p_restaurant_id AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Empleado no pertenece al restaurante';
  END IF;
  period_label_value := CASE WHEN EXTRACT(day FROM period_start_value) = 1
    THEN 'Primera quincena' ELSE 'Segunda quincena' END || ' de ' || (ARRAY[
    'Enero','Febrero','Marzo','Abril','Mayo','Junio',
    'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
  ])[EXTRACT(month FROM period_start_value)::int] ||
  ' ' || EXTRACT(year FROM period_start_value)::int;
  SELECT line.id, line.payroll_run_id, line.base_salary,
         line.staff_consumption_amount,
         line.raw_material_consumption_amount,
         line.salary_advance_deduction,
         COALESCE((line.details ->> 'overtime_amount')::numeric, 0)
           AS overtime_amount,
         line.net_pay, line.paid_amount, line.balance_amount
    INTO existing_line
    FROM public.payroll_run_lines line
    JOIN public.payroll_runs run ON run.id = line.payroll_run_id
   WHERE run.restaurant_id = p_restaurant_id
     AND run.period_start = period_start_value
     AND run.period_end = period_end_value
     AND run.status <> 'voided'
     AND line.employee_id = employee_id_value
   FOR UPDATE;
  IF existing_line.id IS NOT NULL THEN
    IF existing_line.balance_amount <= 0 THEN
      RAISE EXCEPTION 'La planilla del empleado ya esta pagada';
    END IF;
    IF payment_amount_value > existing_line.balance_amount THEN
      RAISE EXCEPTION 'Monto de pago mayor al saldo pendiente';
    END IF;
    UPDATE public.payroll_run_lines
       SET paid_amount = paid_amount + payment_amount_value,
           balance_amount = GREATEST(balance_amount - payment_amount_value, 0),
           details = details || jsonb_build_object(
             'last_payment_by', auth.uid(),
             'last_payment_at', now()
           )
     WHERE id = existing_line.id
     RETURNING id, payroll_run_id, paid_amount, balance_amount
          INTO line_id_value, payroll_run_id_value,
               paid_amount_after_value, balance_after_value;
    SELECT COALESCE(SUM(balance_amount), 0)
      INTO advance_balance_after_value
      FROM public.employee_salary_advances
     WHERE restaurant_id = p_restaurant_id
       AND employee_id = employee_id_value;
    INSERT INTO public.payroll_payment_receipts (
      restaurant_id, payroll_run_id, payroll_run_line_id, employee_id,
      period_start, period_end, period_label, base_salary, overtime_amount,
      staff_consumption_amount, raw_material_consumption_amount,
      salary_advance_deduction, net_pay, payment_amount,
      line_paid_amount_after, line_balance_amount_after,
      advance_balance_after, created_by_user_id, details
    )
    VALUES (
      p_restaurant_id, payroll_run_id_value, line_id_value, employee_id_value,
      period_start_value, period_end_value, period_label_value,
      existing_line.base_salary, existing_line.overtime_amount, 0, 0, 0,
      existing_line.balance_amount, payment_amount_value,
      paid_amount_after_value, balance_after_value,
      advance_balance_after_value, auth.uid(),
      jsonb_build_object('partial_payment', true)
    )
    RETURNING id INTO receipt_id_value;
    RETURN jsonb_build_object('payroll_run_id', payroll_run_id_value,
      'payroll_line_id', line_id_value, 'payment_receipt_id', receipt_id_value);
  END IF;
  SELECT COALESCE(SUM(total_amount), 0)
    INTO pos_consumption_value
    FROM public.sales
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = employee_id_value
     AND sale_kind = 'staff_consumption'
     AND payroll_run_id IS NULL
     AND sold_at::date BETWEEN period_start_value AND period_end_value;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'receipt', COALESCE(invoice_number, 'CP-' || internal_receipt_number::text),
           'date', sold_at,
           'amount', total_amount
         ) ORDER BY sold_at), '[]'::jsonb)
    INTO consumption_details
    FROM public.sales
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = employee_id_value
     AND sale_kind = 'staff_consumption'
     AND payroll_run_id IS NULL
     AND sold_at::date BETWEEN period_start_value AND period_end_value;
  raw_consumption_value := public.app_get_employee_raw_material_payroll_total(
    p_restaurant_id, employee_id_value, period_start_value, period_end_value);
  SELECT COALESCE(SUM(total_amount), 0)
    INTO overtime_value
    FROM public.employee_overtime_entries
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = employee_id_value
     AND status = 'pending'
     AND worked_date BETWEEN period_start_value AND period_end_value;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'overtime_id', id,
           'date', worked_date,
           'hours', hours,
           'hour_rate', hour_rate,
           'amount', total_amount,
           'note', note
         ) ORDER BY worked_date, created_at), '[]'::jsonb)
    INTO overtime_details
    FROM public.employee_overtime_entries
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = employee_id_value
     AND status = 'pending'
     AND worked_date BETWEEN period_start_value AND period_end_value;
  total_consumption_value := pos_consumption_value + raw_consumption_value;
  net_pay_value := base_salary_value + overtime_value
    - total_consumption_value - requested_advance_deduction;
  IF net_pay_value <= 0 THEN
    RAISE EXCEPTION 'La planilla del empleado no tiene saldo a pagar';
  END IF;
  IF payment_amount_value > net_pay_value THEN
    RAISE EXCEPTION 'Monto de pago mayor al saldo de nomina';
  END IF;
  SELECT id INTO payroll_run_id_value
    FROM public.payroll_runs
   WHERE restaurant_id = p_restaurant_id
     AND period_start = period_start_value
     AND period_end = period_end_value
     AND status <> 'voided'
   LIMIT 1;
  IF payroll_run_id_value IS NULL THEN
    INSERT INTO public.payroll_runs (
      restaurant_id, period_start, period_end, status,
      created_by_user_id, posted_at
    )
    VALUES (
      p_restaurant_id, period_start_value, period_end_value, 'posted',
      auth.uid(), now()
    )
    RETURNING id INTO payroll_run_id_value;
  END IF;
  remaining_deduction := requested_advance_deduction;
  IF remaining_deduction < 0 THEN
    RAISE EXCEPTION 'Abono de adelanto invalido';
  END IF;
  FOR advance_row IN
    SELECT id, amount, balance_amount, delivered_at, created_at
      FROM public.employee_salary_advances
     WHERE restaurant_id = p_restaurant_id
       AND employee_id = employee_id_value
       AND status IN ('pending', 'partially_paid')
       AND balance_amount > 0
     ORDER BY delivered_at, created_at, id
     FOR UPDATE
  LOOP
    EXIT WHEN remaining_deduction <= 0;
    deduction_for_row := LEAST(remaining_deduction, advance_row.balance_amount);
    UPDATE public.employee_salary_advances
       SET balance_amount = balance_amount - deduction_for_row,
           status = CASE
             WHEN balance_amount - deduction_for_row <= 0 THEN 'paid'
             ELSE 'partially_paid'
           END,
           updated_at = now()
     WHERE id = advance_row.id;
    advance_details := advance_details || jsonb_build_array(
      jsonb_build_object(
        'advance_id', advance_row.id,
        'delivered_at', advance_row.delivered_at,
        'original_amount', advance_row.amount,
        'applied_amount', deduction_for_row,
        'balance_after', advance_row.balance_amount - deduction_for_row
      )
    );
    remaining_deduction := remaining_deduction - deduction_for_row;
  END LOOP;
  IF remaining_deduction > 0 THEN
    RAISE EXCEPTION 'Abono mayor al saldo pendiente de adelantos';
  END IF;
  UPDATE public.sales
     SET payroll_run_id = payroll_run_id_value,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = employee_id_value
     AND sale_kind = 'staff_consumption'
     AND payroll_run_id IS NULL
     AND sold_at::date BETWEEN period_start_value AND period_end_value;
  raw_details := public.app_mark_raw_material_consumptions_paid(
    p_restaurant_id, employee_id_value, period_start_value, period_end_value,
    payroll_run_id_value);
  balance_amount_value := net_pay_value - payment_amount_value;
  INSERT INTO public.payroll_run_lines (
    payroll_run_id, employee_id, base_salary, staff_consumption_amount,
    raw_material_consumption_amount, salary_advance_deduction, net_pay,
    paid_amount, balance_amount, details
  )
  VALUES (
    payroll_run_id_value, employee_id_value, base_salary_value,
    pos_consumption_value, raw_consumption_value,
    requested_advance_deduction, net_pay_value, payment_amount_value,
    balance_amount_value, jsonb_build_object(
      'posted_by', auth.uid(),
      'posted_at', now(),
      'overtime_amount', overtime_value
    )
  )
  RETURNING id INTO line_id_value;
  UPDATE public.employee_overtime_entries
     SET status = 'paid',
         payroll_run_id = payroll_run_id_value,
         payroll_run_line_id = line_id_value,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = employee_id_value
     AND status = 'pending'
     AND worked_date BETWEEN period_start_value AND period_end_value;
  SELECT COALESCE(SUM(balance_amount), 0)
    INTO advance_balance_after_value
    FROM public.employee_salary_advances
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = employee_id_value;
  INSERT INTO public.payroll_payment_receipts (
    restaurant_id, payroll_run_id, payroll_run_line_id, employee_id,
    period_start, period_end, period_label, base_salary, overtime_amount,
    staff_consumption_amount, raw_material_consumption_amount,
    salary_advance_deduction, net_pay, payment_amount,
    line_paid_amount_after, line_balance_amount_after, advance_balance_after,
    created_by_user_id, details
  )
  VALUES (
    p_restaurant_id, payroll_run_id_value, line_id_value, employee_id_value,
    period_start_value, period_end_value, period_label_value,
    base_salary_value, overtime_value, pos_consumption_value,
    raw_consumption_value, requested_advance_deduction, net_pay_value,
    payment_amount_value, payment_amount_value, balance_amount_value,
    advance_balance_after_value, auth.uid(), jsonb_build_object(
      'consumptions', consumption_details,
      'raw_material_consumptions', raw_details,
      'salary_advances', advance_details,
      'overtime_entries', overtime_details
    )
  )
  RETURNING id INTO receipt_id_value;
  RETURN jsonb_build_object('payroll_run_id', payroll_run_id_value,
    'payroll_line_id', line_id_value, 'payment_receipt_id', receipt_id_value);
END;
$$;
GRANT EXECUTE ON FUNCTION public.app_post_payroll_employee(uuid, jsonb)
  TO authenticated;
