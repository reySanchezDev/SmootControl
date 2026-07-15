CREATE TABLE IF NOT EXISTS public.payroll_payment_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  payroll_run_id uuid NOT NULL REFERENCES public.payroll_runs(id) ON DELETE CASCADE,
  payroll_run_line_id uuid NOT NULL REFERENCES public.payroll_run_lines(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id),
  period_start date NOT NULL,
  period_end date NOT NULL,
  period_label text NOT NULL,
  base_salary numeric(15, 4) NOT NULL DEFAULT 0,
  staff_consumption_amount numeric(15, 4) NOT NULL DEFAULT 0,
  salary_advance_deduction numeric(15, 4) NOT NULL DEFAULT 0,
  net_pay numeric(15, 4) NOT NULL DEFAULT 0,
  payment_amount numeric(15, 4) NOT NULL CHECK (payment_amount > 0),
  line_paid_amount_after numeric(15, 4) NOT NULL DEFAULT 0,
  line_balance_amount_after numeric(15, 4) NOT NULL DEFAULT 0,
  advance_balance_after numeric(15, 4) NOT NULL DEFAULT 0,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  paid_at timestamptz NOT NULL DEFAULT now(),
  created_by_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payroll_payment_receipts_restaurant_paid_idx
  ON public.payroll_payment_receipts (restaurant_id, paid_at DESC);

CREATE INDEX IF NOT EXISTS payroll_payment_receipts_employee_paid_idx
  ON public.payroll_payment_receipts (employee_id, paid_at DESC);

ALTER TABLE public.payroll_payment_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payroll_payment_receipts_same_restaurant
  ON public.payroll_payment_receipts;
CREATE POLICY payroll_payment_receipts_same_restaurant
  ON public.payroll_payment_receipts
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

INSERT INTO public.payroll_payment_receipts (
  restaurant_id,
  payroll_run_id,
  payroll_run_line_id,
  employee_id,
  period_start,
  period_end,
  period_label,
  base_salary,
  staff_consumption_amount,
  salary_advance_deduction,
  net_pay,
  payment_amount,
  line_paid_amount_after,
  line_balance_amount_after,
  advance_balance_after,
  paid_at,
  created_by_user_id,
  details
)
SELECT run.restaurant_id,
       line.payroll_run_id,
       line.id,
       line.employee_id,
       run.period_start,
       run.period_end,
       CASE
         WHEN EXTRACT(day FROM run.period_start) = 1
           THEN 'Primera quincena'
         ELSE 'Segunda quincena'
       END || ' de ' ||
       CASE EXTRACT(month FROM run.period_start)::int
         WHEN 1 THEN 'Enero'
         WHEN 2 THEN 'Febrero'
         WHEN 3 THEN 'Marzo'
         WHEN 4 THEN 'Abril'
         WHEN 5 THEN 'Mayo'
         WHEN 6 THEN 'Junio'
         WHEN 7 THEN 'Julio'
         WHEN 8 THEN 'Agosto'
         WHEN 9 THEN 'Septiembre'
         WHEN 10 THEN 'Octubre'
         WHEN 11 THEN 'Noviembre'
         ELSE 'Diciembre'
       END || ' ' || EXTRACT(year FROM run.period_start)::int,
       line.base_salary,
       line.staff_consumption_amount,
       line.salary_advance_deduction,
       line.net_pay,
       line.paid_amount,
       line.paid_amount,
       line.balance_amount,
       COALESCE((
         SELECT SUM(balance_amount)
           FROM public.employee_salary_advances advance
          WHERE advance.restaurant_id = run.restaurant_id
            AND advance.employee_id = line.employee_id
       ), 0),
       COALESCE((line.details ->> 'last_payment_at')::timestamptz, run.posted_at, run.created_at),
       run.created_by_user_id,
       jsonb_build_object('backfilled', true)
  FROM public.payroll_run_lines line
  JOIN public.payroll_runs run
    ON run.id = line.payroll_run_id
 WHERE line.paid_amount > 0
   AND NOT EXISTS (
     SELECT 1
       FROM public.payroll_payment_receipts receipt
      WHERE receipt.payroll_run_line_id = line.id
   );

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
      JOIN public.employees employee
        ON employee.id = receipt.employee_id
      LEFT JOIN public.employee_positions position
        ON position.id = employee.position_id
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
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'planilla.gestionar'
  );

  employee_id_value := (p_payload ->> 'employee_id')::uuid;
  period_start_value := (p_payload ->> 'period_start')::date;
  period_end_value := (p_payload ->> 'period_end')::date;
  base_salary_value := COALESCE((p_payload ->> 'base_salary')::numeric, 0);
  requested_advance_deduction := COALESCE(
    (p_payload ->> 'salary_advance_deduction')::numeric,
    0
  );
  payment_amount_value := COALESCE(
    (p_payload ->> 'payment_amount')::numeric,
    0
  );

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
  CASE EXTRACT(month FROM period_start_value)::int
    WHEN 1 THEN 'Enero'
    WHEN 2 THEN 'Febrero'
    WHEN 3 THEN 'Marzo'
    WHEN 4 THEN 'Abril'
    WHEN 5 THEN 'Mayo'
    WHEN 6 THEN 'Junio'
    WHEN 7 THEN 'Julio'
    WHEN 8 THEN 'Agosto'
    WHEN 9 THEN 'Septiembre'
    WHEN 10 THEN 'Octubre'
    WHEN 11 THEN 'Noviembre'
    ELSE 'Diciembre'
  END || ' ' || EXTRACT(year FROM period_start_value)::int;

  SELECT run_line.id,
         run_line.payroll_run_id,
         run_line.base_salary,
         run_line.staff_consumption_amount,
         run_line.salary_advance_deduction,
         run_line.net_pay,
         run_line.paid_amount,
         run_line.balance_amount
    INTO existing_line
    FROM public.payroll_run_lines run_line
    JOIN public.payroll_runs run
      ON run.id = run_line.payroll_run_id
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
           balance_amount = GREATEST(
             balance_amount - payment_amount_value,
             0
           ),
           details = details || jsonb_build_object(
             'last_payment_by',
             auth.uid(),
             'last_payment_at',
             now()
           )
     WHERE id = existing_line.id
     RETURNING id,
               payroll_run_id,
               paid_amount,
               balance_amount
          INTO line_id_value,
               payroll_run_id_value,
               paid_amount_after_value,
               balance_after_value;

    SELECT COALESCE(SUM(balance_amount), 0)
      INTO advance_balance_after_value
      FROM public.employee_salary_advances
     WHERE restaurant_id = p_restaurant_id
       AND employee_id = employee_id_value;

    INSERT INTO public.payroll_payment_receipts (
      restaurant_id,
      payroll_run_id,
      payroll_run_line_id,
      employee_id,
      period_start,
      period_end,
      period_label,
      base_salary,
      staff_consumption_amount,
      salary_advance_deduction,
      net_pay,
      payment_amount,
      line_paid_amount_after,
      line_balance_amount_after,
      advance_balance_after,
      created_by_user_id,
      details
    )
    VALUES (
      p_restaurant_id,
      payroll_run_id_value,
      line_id_value,
      employee_id_value,
      period_start_value,
      period_end_value,
      period_label_value,
      existing_line.base_salary,
      0,
      0,
      existing_line.balance_amount,
      payment_amount_value,
      paid_amount_after_value,
      balance_after_value,
      advance_balance_after_value,
      auth.uid(),
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

  SELECT COALESCE(
           jsonb_agg(
             jsonb_build_object(
               'receipt', COALESCE(invoice_number, 'CP-' || internal_receipt_number::text),
               'date', sold_at,
               'amount', total_amount
             )
             ORDER BY sold_at
           ),
           '[]'::jsonb
         )
    INTO consumption_details
    FROM public.sales
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = employee_id_value
     AND sale_kind = 'staff_consumption'
     AND payroll_run_id IS NULL
     AND sold_at::date BETWEEN period_start_value AND period_end_value;

  net_pay_value := base_salary_value - consumption_value
    - requested_advance_deduction;

  IF net_pay_value <= 0 THEN
    RAISE EXCEPTION 'La planilla del empleado no tiene saldo a pagar';
  END IF;

  IF payment_amount_value > net_pay_value THEN
    RAISE EXCEPTION 'Monto de pago mayor al saldo de nomina';
  END IF;

  SELECT id
    INTO payroll_run_id_value
    FROM public.payroll_runs
   WHERE restaurant_id = p_restaurant_id
     AND period_start = period_start_value
     AND period_end = period_end_value
     AND status <> 'voided'
   LIMIT 1;

  IF payroll_run_id_value IS NULL THEN
    INSERT INTO public.payroll_runs (
      restaurant_id,
      period_start,
      period_end,
      status,
      created_by_user_id,
      posted_at
    )
    VALUES (
      p_restaurant_id,
      period_start_value,
      period_end_value,
      'posted',
      auth.uid(),
      now()
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
    payroll_run_id,
    employee_id,
    base_salary,
    staff_consumption_amount,
    salary_advance_deduction,
    net_pay,
    paid_amount,
    balance_amount,
    details
  )
  VALUES (
    payroll_run_id_value,
    employee_id_value,
    base_salary_value,
    consumption_value,
    requested_advance_deduction,
    net_pay_value,
    payment_amount_value,
    balance_amount_value,
    jsonb_build_object('posted_by', auth.uid(), 'posted_at', now())
  )
  RETURNING id INTO line_id_value;

  SELECT COALESCE(SUM(balance_amount), 0)
    INTO advance_balance_after_value
    FROM public.employee_salary_advances
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = employee_id_value;

  INSERT INTO public.payroll_payment_receipts (
    restaurant_id,
    payroll_run_id,
    payroll_run_line_id,
    employee_id,
    period_start,
    period_end,
    period_label,
    base_salary,
    staff_consumption_amount,
    salary_advance_deduction,
    net_pay,
    payment_amount,
    line_paid_amount_after,
    line_balance_amount_after,
    advance_balance_after,
    created_by_user_id,
    details
  )
  VALUES (
    p_restaurant_id,
    payroll_run_id_value,
    line_id_value,
    employee_id_value,
    period_start_value,
    period_end_value,
    period_label_value,
    base_salary_value,
    consumption_value,
    requested_advance_deduction,
    net_pay_value,
    payment_amount_value,
    payment_amount_value,
    balance_amount_value,
    advance_balance_after_value,
    auth.uid(),
    jsonb_build_object(
      'consumptions', consumption_details,
      'salary_advances', advance_details
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

REVOKE ALL ON FUNCTION public.app_get_paid_payroll_receipts(uuid, date, date, text)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_post_payroll_employee(uuid, jsonb)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_get_paid_payroll_receipts(uuid, date, date, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_post_payroll_employee(uuid, jsonb)
  TO authenticated;
