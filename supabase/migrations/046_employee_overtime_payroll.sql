ALTER TABLE public.payroll_payment_receipts
  ADD COLUMN IF NOT EXISTS overtime_amount numeric(15, 4) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.employee_overtime_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id),
  worked_date date NOT NULL,
  hours numeric(10, 2) NOT NULL CHECK (hours > 0),
  hour_rate numeric(15, 4) NOT NULL CHECK (hour_rate >= 0),
  total_amount numeric(15, 4) NOT NULL CHECK (total_amount >= 0),
  note text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'paid')),
  payroll_run_id uuid REFERENCES public.payroll_runs(id) ON DELETE SET NULL,
  payroll_run_line_id uuid REFERENCES public.payroll_run_lines(id) ON DELETE SET NULL,
  created_by_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS employee_overtime_entries_restaurant_date_idx
  ON public.employee_overtime_entries (restaurant_id, worked_date DESC);

CREATE INDEX IF NOT EXISTS employee_overtime_entries_employee_status_idx
  ON public.employee_overtime_entries (employee_id, status, worked_date);

ALTER TABLE public.employee_overtime_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS employee_overtime_entries_same_restaurant
  ON public.employee_overtime_entries;
CREATE POLICY employee_overtime_entries_same_restaurant
  ON public.employee_overtime_entries
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

INSERT INTO public.business_rules (restaurant_id, key, text_value, bool_value)
SELECT id, 'overtime_hour_rate', '0', NULL
  FROM public.restaurants
ON CONFLICT (restaurant_id, key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.app_get_employee_overtime_entries(
  p_restaurant_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'planilla.gestionar');

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', overtime.id,
        'employee_id', overtime.employee_id,
        'employee_name', employee.full_name,
        'worked_date', overtime.worked_date,
        'hours', overtime.hours,
        'hour_rate', overtime.hour_rate,
        'total_amount', overtime.total_amount,
        'note', overtime.note,
        'status', overtime.status,
        'payroll_run_id', overtime.payroll_run_id,
        'payroll_run_line_id', overtime.payroll_run_line_id,
        'created_at', overtime.created_at
      )
      ORDER BY overtime.worked_date DESC, overtime.created_at DESC
    )
      FROM public.employee_overtime_entries overtime
      JOIN public.employees employee ON employee.id = overtime.employee_id
     WHERE overtime.restaurant_id = p_restaurant_id
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_save_employee_overtime_entry(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  entry_id uuid;
  employee_id_value uuid;
  worked_date_value date;
  hours_value numeric;
  rate_value numeric;
  note_value text;
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'planilla.gestionar');

  entry_id := COALESCE((p_payload ->> 'id')::uuid, gen_random_uuid());
  employee_id_value := (p_payload ->> 'employee_id')::uuid;
  worked_date_value := (p_payload ->> 'worked_date')::date;
  hours_value := COALESCE((p_payload ->> 'hours')::numeric, 0);
  note_value := NULLIF(trim(COALESCE(p_payload ->> 'note', '')), '');

  IF hours_value <= 0 THEN
    RAISE EXCEPTION 'Horas extras invalidas';
  END IF;

  SELECT COALESCE(NULLIF(text_value, '')::numeric, 0)
    INTO rate_value
    FROM public.business_rules
   WHERE restaurant_id = p_restaurant_id
     AND key = 'overtime_hour_rate';

  IF rate_value IS NULL OR rate_value <= 0 THEN
    RAISE EXCEPTION 'Configura el valor de la hora extra';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value
       AND restaurant_id = p_restaurant_id
       AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Empleado no pertenece al restaurante';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.employee_overtime_entries
     WHERE id = entry_id
       AND status = 'paid'
  ) THEN
    RAISE EXCEPTION 'No se puede editar una hora extra pagada';
  END IF;

  INSERT INTO public.employee_overtime_entries (
    id, restaurant_id, employee_id, worked_date, hours, hour_rate,
    total_amount, note, created_by_user_id
  )
  VALUES (
    entry_id, p_restaurant_id, employee_id_value, worked_date_value,
    hours_value, rate_value, ROUND(hours_value * rate_value, 2),
    note_value, auth.uid()
  )
  ON CONFLICT (id) DO UPDATE
     SET employee_id = EXCLUDED.employee_id,
         worked_date = EXCLUDED.worked_date,
         hours = EXCLUDED.hours,
         hour_rate = EXCLUDED.hour_rate,
         total_amount = EXCLUDED.total_amount,
         note = EXCLUDED.note,
         updated_at = now()
   WHERE employee_overtime_entries.status = 'pending';

  RETURN jsonb_build_object('id', entry_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_delete_employee_overtime_entry(
  p_restaurant_id uuid,
  p_overtime_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'planilla.gestionar');

  DELETE FROM public.employee_overtime_entries
   WHERE id = p_overtime_id
     AND restaurant_id = p_restaurant_id
     AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se puede eliminar una hora extra pagada';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_get_pending_payroll_lines(
  p_restaurant_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'planilla.gestionar');

  RETURN COALESCE((
    SELECT jsonb_agg(to_jsonb(row_data) ORDER BY period_start, employee_name)
      FROM (
        SELECT run_line.payroll_run_id,
               run_line.employee_id,
               employee.full_name AS employee_name,
               run.period_start,
               run.period_end,
               (
                 CASE WHEN EXTRACT(DAY FROM run.period_start) <= 15
                   THEN 'Primera quincena'
                   ELSE 'Segunda quincena'
                 END
               ) || ' de ' ||
               (ARRAY[
                 'Enero','Febrero','Marzo','Abril','Mayo','Junio',
                 'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
               ])[EXTRACT(MONTH FROM run.period_start)::integer] ||
               ' ' || EXTRACT(YEAR FROM run.period_start)::integer
                 AS period_label,
               run_line.base_salary,
               run_line.staff_consumption_amount,
               run_line.salary_advance_deduction,
               COALESCE((run_line.details ->> 'overtime_amount')::numeric, 0)
                 AS overtime_amount,
               run_line.net_pay,
               run_line.paid_amount,
               run_line.balance_amount
          FROM public.payroll_run_lines run_line
          JOIN public.payroll_runs run ON run.id = run_line.payroll_run_id
          JOIN public.employees employee ON employee.id = run_line.employee_id
         WHERE run.restaurant_id = p_restaurant_id
           AND run.status <> 'voided'
           AND (
             (
               run_line.balance_amount > 0
               AND run_line.paid_amount +
                 run_line.salary_advance_deduction < run_line.net_pay
             )
             OR run.period_end >= CURRENT_DATE - INTERVAL '45 days'
           )
      ) row_data
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_get_paid_payroll_receipts(
  p_restaurant_id uuid,
  p_from date,
  p_to date,
  p_cut text DEFAULT 'all'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'reportes.ver');

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', receipt.id,
        'payroll_run_id', receipt.payroll_run_id,
        'payroll_run_line_id', receipt.payroll_run_line_id,
        'employee_id', receipt.employee_id,
        'employee_name', employee.full_name,
        'employee_code', COALESCE(employee.code, employee.employee_number::text),
        'position_name', COALESCE(position.name, employee.position_name, ''),
        'period_start', receipt.period_start,
        'period_end', receipt.period_end,
        'period_label', receipt.period_label,
        'base_salary', receipt.base_salary,
        'overtime_amount', receipt.overtime_amount,
        'staff_consumption_amount', receipt.staff_consumption_amount,
        'salary_advance_deduction', receipt.salary_advance_deduction,
        'net_pay', receipt.net_pay,
        'payment_amount', receipt.payment_amount,
        'line_paid_amount_after', receipt.line_paid_amount_after,
        'line_balance_amount_after', receipt.line_balance_amount_after,
        'advance_balance_after', receipt.advance_balance_after,
        'details', receipt.details,
        'paid_at', receipt.paid_at
      )
      ORDER BY receipt.paid_at DESC, receipt.id DESC
    )
      FROM public.payroll_payment_receipts receipt
      JOIN public.employees employee ON employee.id = receipt.employee_id
      LEFT JOIN public.employee_positions position ON position.id = employee.position_id
     WHERE receipt.restaurant_id = p_restaurant_id
       AND receipt.paid_at::date BETWEEN p_from AND p_to
       AND (
         p_cut = 'all'
         OR (p_cut = 'first' AND EXTRACT(day FROM receipt.period_start) = 1)
         OR (p_cut = 'second' AND EXTRACT(day FROM receipt.period_start) <> 1)
       )
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.app_get_employee_overtime_entries(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_save_employee_overtime_entry(uuid, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_delete_employee_overtime_entry(uuid, uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_get_employee_overtime_entries(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_save_employee_overtime_entry(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_delete_employee_overtime_entry(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_get_pending_payroll_lines(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_get_paid_payroll_receipts(uuid, date, date, text) TO authenticated;

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
  employee_id_value uuid;
  period_start_value date;
  period_end_value date;
  period_label_value text;
  payroll_run_id_value uuid;
  line_id_value uuid;
  receipt_id_value uuid;
  base_salary_value numeric;
  consumption_value numeric;
  overtime_value numeric;
  requested_advance_deduction numeric;
  payment_amount_value numeric;
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
  advance_details jsonb := '[]'::jsonb;
  overtime_details jsonb := '[]'::jsonb;
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'planilla.gestionar');

  employee_id_value := (p_payload ->> 'employee_id')::uuid;
  period_start_value := (p_payload ->> 'period_start')::date;
  period_end_value := (p_payload ->> 'period_end')::date;
  base_salary_value := COALESCE((p_payload ->> 'base_salary')::numeric, 0);
  requested_advance_deduction :=
    COALESCE((p_payload ->> 'salary_advance_deduction')::numeric, 0);
  payment_amount_value := COALESCE((p_payload ->> 'payment_amount')::numeric, 0);

  IF payment_amount_value <= 0 THEN
    RAISE EXCEPTION 'Monto de pago invalido';
  END IF;

  IF period_end_value < period_start_value THEN
    RAISE EXCEPTION 'Periodo de planilla invalido';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value
       AND restaurant_id = p_restaurant_id
       AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Empleado no pertenece al restaurante';
  END IF;

  period_label_value := CASE
    WHEN EXTRACT(day FROM period_start_value) = 1 THEN 'Primera quincena'
    ELSE 'Segunda quincena'
  END || ' de ' ||
  (ARRAY[
    'Enero','Febrero','Marzo','Abril','Mayo','Junio',
    'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
  ])[EXTRACT(month FROM period_start_value)::int] ||
  ' ' || EXTRACT(year FROM period_start_value)::int;

  SELECT run_line.id,
         run_line.payroll_run_id,
         run_line.base_salary,
         run_line.staff_consumption_amount,
         run_line.salary_advance_deduction,
         COALESCE((run_line.details ->> 'overtime_amount')::numeric, 0)
           AS overtime_amount,
         run_line.net_pay,
         run_line.paid_amount,
         run_line.balance_amount
    INTO existing_line
    FROM public.payroll_run_lines run_line
    JOIN public.payroll_runs run ON run.id = run_line.payroll_run_id
   WHERE run.restaurant_id = p_restaurant_id
     AND run.period_start = period_start_value
     AND run.period_end = period_end_value
     AND run.status <> 'voided'
     AND run_line.employee_id = employee_id_value
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
      staff_consumption_amount, salary_advance_deduction, net_pay,
      payment_amount, line_paid_amount_after, line_balance_amount_after,
      advance_balance_after, created_by_user_id, details
    )
    VALUES (
      p_restaurant_id, payroll_run_id_value, line_id_value, employee_id_value,
      period_start_value, period_end_value, period_label_value,
      existing_line.base_salary, existing_line.overtime_amount, 0, 0,
      existing_line.balance_amount, payment_amount_value,
      paid_amount_after_value, balance_after_value,
      advance_balance_after_value, auth.uid(),
      jsonb_build_object('partial_payment', true)
    )
    RETURNING id INTO receipt_id_value;

    RETURN jsonb_build_object(
      'payroll_run_id', payroll_run_id_value,
      'payroll_line_id', line_id_value,
      'payment_receipt_id', receipt_id_value
    );
  END IF;

  SELECT COALESCE(SUM(total_amount), 0)
    INTO consumption_value
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

  net_pay_value := base_salary_value + overtime_value - consumption_value
    - requested_advance_deduction;

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

  balance_amount_value := net_pay_value - payment_amount_value;

  INSERT INTO public.payroll_run_lines (
    payroll_run_id, employee_id, base_salary, staff_consumption_amount,
    salary_advance_deduction, net_pay, paid_amount, balance_amount, details
  )
  VALUES (
    payroll_run_id_value, employee_id_value, base_salary_value,
    consumption_value, requested_advance_deduction, net_pay_value,
    payment_amount_value, balance_amount_value,
    jsonb_build_object(
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
    staff_consumption_amount, salary_advance_deduction, net_pay,
    payment_amount, line_paid_amount_after, line_balance_amount_after,
    advance_balance_after, created_by_user_id, details
  )
  VALUES (
    p_restaurant_id, payroll_run_id_value, line_id_value, employee_id_value,
    period_start_value, period_end_value, period_label_value,
    base_salary_value, overtime_value, consumption_value,
    requested_advance_deduction, net_pay_value, payment_amount_value,
    payment_amount_value, balance_amount_value, advance_balance_after_value,
    auth.uid(), jsonb_build_object(
      'consumptions', consumption_details,
      'salary_advances', advance_details,
      'overtime_entries', overtime_details
    )
  )
  RETURNING id INTO receipt_id_value;

  RETURN jsonb_build_object(
    'payroll_run_id', payroll_run_id_value,
    'payroll_line_id', line_id_value,
    'payment_receipt_id', receipt_id_value
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_post_payroll_employee(uuid, jsonb)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.app_reverse_payroll_payment_receipt(
  p_restaurant_id uuid,
  p_receipt_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  receipt_row record;
  remaining_receipts integer;
  restored_advances integer := 0;
  restored_consumptions integer := 0;
  restored_overtime integer := 0;
  deleted_lines integer := 0;
  deleted_runs integer := 0;
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'planilla.gestionar');

  SELECT *
    INTO receipt_row
    FROM public.payroll_payment_receipts
   WHERE id = p_receipt_id
     AND restaurant_id = p_restaurant_id
   FOR UPDATE;

  IF receipt_row.id IS NULL THEN
    RAISE EXCEPTION 'Pago de planilla no encontrado';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.payroll_payment_receipts newer
     WHERE newer.payroll_run_line_id = receipt_row.payroll_run_line_id
       AND newer.paid_at > receipt_row.paid_at
  ) THEN
    RAISE EXCEPTION 'Primero elimina los pagos posteriores de esta planilla';
  END IF;

  SELECT count(*)
    INTO remaining_receipts
    FROM public.payroll_payment_receipts
   WHERE payroll_run_line_id = receipt_row.payroll_run_line_id
     AND id <> receipt_row.id;

  DELETE FROM public.payroll_payment_receipts
   WHERE id = receipt_row.id;

  IF remaining_receipts > 0 THEN
    UPDATE public.payroll_run_lines
       SET paid_amount = GREATEST(paid_amount - receipt_row.payment_amount, 0),
           balance_amount = balance_amount + receipt_row.payment_amount,
           details = details || jsonb_build_object(
             'last_reversed_receipt_id', receipt_row.id,
             'last_reversed_at', now()
           )
     WHERE id = receipt_row.payroll_run_line_id;

    RETURN jsonb_build_object(
      'deleted_receipts', 1,
      'restored_advances', 0,
      'restored_consumptions', 0,
      'restored_overtime', 0,
      'deleted_lines', 0,
      'deleted_runs', 0
    );
  END IF;

  WITH advance_rows AS (
    SELECT (item ->> 'advance_id')::uuid AS advance_id,
           COALESCE((item ->> 'applied_amount')::numeric, 0) AS amount
      FROM jsonb_array_elements(
        COALESCE(receipt_row.details -> 'salary_advances', '[]'::jsonb)
      ) item
  ),
  restored AS (
    UPDATE public.employee_salary_advances advance
       SET balance_amount = advance.balance_amount + advance_rows.amount,
           status = CASE
             WHEN advance.balance_amount + advance_rows.amount >= advance.amount
               THEN 'pending'
             WHEN advance.balance_amount + advance_rows.amount <= 0
               THEN 'paid'
             ELSE 'partially_paid'
           END,
           updated_at = now()
      FROM advance_rows
     WHERE advance.id = advance_rows.advance_id
       AND advance.restaurant_id = p_restaurant_id
    RETURNING advance.id
  )
  SELECT count(*) INTO restored_advances FROM restored;

  UPDATE public.sales
     SET payroll_run_id = NULL,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = receipt_row.employee_id
     AND sale_kind = 'staff_consumption'
     AND payroll_run_id = receipt_row.payroll_run_id;
  GET DIAGNOSTICS restored_consumptions = ROW_COUNT;

  UPDATE public.employee_overtime_entries
     SET status = 'pending',
         payroll_run_id = NULL,
         payroll_run_line_id = NULL,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = receipt_row.employee_id
     AND payroll_run_id = receipt_row.payroll_run_id
     AND payroll_run_line_id = receipt_row.payroll_run_line_id;
  GET DIAGNOSTICS restored_overtime = ROW_COUNT;

  DELETE FROM public.payroll_run_lines
   WHERE id = receipt_row.payroll_run_line_id
     AND payroll_run_id = receipt_row.payroll_run_id;
  GET DIAGNOSTICS deleted_lines = ROW_COUNT;

  DELETE FROM public.payroll_runs run
   WHERE run.id = receipt_row.payroll_run_id
     AND NOT EXISTS (
       SELECT 1 FROM public.payroll_run_lines line
        WHERE line.payroll_run_id = run.id
     );
  GET DIAGNOSTICS deleted_runs = ROW_COUNT;

  RETURN jsonb_build_object(
    'deleted_receipts', 1,
    'restored_advances', restored_advances,
    'restored_consumptions', restored_consumptions,
    'restored_overtime', restored_overtime,
    'deleted_lines', deleted_lines,
    'deleted_runs', deleted_runs
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_reverse_payroll_payment_receipt(uuid, uuid)
  TO authenticated;
