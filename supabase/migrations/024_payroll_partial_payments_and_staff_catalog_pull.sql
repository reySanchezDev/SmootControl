ALTER TABLE public.payroll_run_lines
  ADD COLUMN IF NOT EXISTS paid_amount numeric(15, 4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS balance_amount numeric(15, 4) NOT NULL DEFAULT 0;

UPDATE public.payroll_run_lines
   SET paid_amount = net_pay,
       balance_amount = 0
 WHERE paid_amount = 0
   AND balance_amount = 0;

CREATE OR REPLACE FUNCTION public.app_get_pending_payroll_lines(
  p_restaurant_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'planilla.gestionar'
  );

  SELECT COALESCE(jsonb_agg(to_jsonb(row_data)), '[]'::jsonb)
    INTO result
    FROM (
      SELECT run_line.payroll_run_id,
             run_line.employee_id,
             employee.full_name AS employee_name,
             run.period_start,
             run.period_end,
             (
               CASE
                 WHEN EXTRACT(DAY FROM run.period_start) <= 15
                   THEN 'Primera quincena'
                 ELSE 'Segunda quincena'
               END
             ) || ' de ' ||
             (
               ARRAY[
                 'Enero',
                 'Febrero',
                 'Marzo',
                 'Abril',
                 'Mayo',
                 'Junio',
                 'Julio',
                 'Agosto',
                 'Septiembre',
                 'Octubre',
                 'Noviembre',
                 'Diciembre'
               ]
             )[EXTRACT(MONTH FROM run.period_start)::integer] ||
             ' ' || EXTRACT(YEAR FROM run.period_start)::integer
               AS period_label,
             run_line.base_salary,
             run_line.staff_consumption_amount,
             run_line.salary_advance_deduction,
             run_line.net_pay,
             run_line.paid_amount,
             run_line.balance_amount
        FROM public.payroll_run_lines run_line
        JOIN public.payroll_runs run
          ON run.id = run_line.payroll_run_id
        JOIN public.employees employee
          ON employee.id = run_line.employee_id
       WHERE run.restaurant_id = p_restaurant_id
         AND run.status <> 'voided'
         AND run_line.balance_amount > 0
       ORDER BY run.period_start, employee.full_name
    ) row_data;

  RETURN result;
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
  payroll_run_id_value uuid;
  line_id_value uuid;
  base_salary_value numeric;
  consumption_value numeric;
  requested_advance_deduction numeric;
  payment_amount_value numeric;
  net_pay_value numeric;
  balance_amount_value numeric;
  remaining_deduction numeric;
  advance_row record;
  deduction_for_row numeric;
  existing_line record;
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

  SELECT run_line.id,
         run_line.payroll_run_id,
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
     RETURNING id, payroll_run_id
          INTO line_id_value, payroll_run_id_value;

    RETURN jsonb_build_object(
      'payroll_run_id', payroll_run_id_value,
      'payroll_line_id', line_id_value
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
    SELECT id, balance_amount
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

  RETURN jsonb_build_object(
    'payroll_run_id', payroll_run_id_value,
    'payroll_line_id', line_id_value
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_pull_operational_catalog(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  INSERT INTO public.sales_types (
    restaurant_id,
    code,
    name,
    display_order,
    is_default,
    is_active
  )
  VALUES
    (p_restaurant_id, 'dine_in', 'Comer aqui', 0, true, true),
    (p_restaurant_id, 'to_go', 'Para llevar', 1, false, true)
  ON CONFLICT (restaurant_id, code) DO NOTHING;

  INSERT INTO public.business_rules (restaurant_id, key, bool_value)
  VALUES (
    p_restaurant_id,
    'salary_advance_pos_affects_cash',
    false
  )
  ON CONFLICT (restaurant_id, key) DO NOTHING;

  RETURN jsonb_build_object(
    'restaurants', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.restaurants
           WHERE id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'invoice_number_settings', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.invoice_number_settings
           WHERE restaurant_id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'permissions', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.permissions
        ) row_data
    ), '[]'::jsonb),
    'roles', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.roles
           WHERE restaurant_id = p_restaurant_id
              OR restaurant_id IS NULL
        ) row_data
    ), '[]'::jsonb),
    'role_permissions', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT role_permission.role_id,
                 role_permission.permission_id
            FROM public.role_permissions role_permission
            JOIN public.roles role_row
              ON role_row.id = role_permission.role_id
           WHERE role_row.restaurant_id = p_restaurant_id
              OR role_row.restaurant_id IS NULL
        ) row_data
    ), '[]'::jsonb),
    'profiles', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.profiles
           WHERE restaurant_id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'product_categories', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.product_categories
           WHERE restaurant_id = p_restaurant_id
           ORDER BY display_order, name
        ) row_data
    ), '[]'::jsonb),
    'modifier_groups', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.modifier_groups
           WHERE restaurant_id = p_restaurant_id
           ORDER BY display_order, name
        ) row_data
    ), '[]'::jsonb),
    'modifier_options', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.modifier_options
           WHERE restaurant_id = p_restaurant_id
           ORDER BY display_order, name
        ) row_data
    ), '[]'::jsonb),
    'product_modifier_groups', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.product_modifier_groups
           WHERE restaurant_id = p_restaurant_id
           ORDER BY display_order
        ) row_data
    ), '[]'::jsonb),
    'products', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.products
           WHERE restaurant_id = p_restaurant_id
           ORDER BY name
        ) row_data
    ), '[]'::jsonb),
    'inventory_stock', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.inventory_stock
           WHERE restaurant_id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'sales_types', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.sales_types
           WHERE restaurant_id = p_restaurant_id
           ORDER BY display_order, name
        ) row_data
    ), '[]'::jsonb),
    'packaging_items', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.packaging_items
           WHERE restaurant_id = p_restaurant_id
           ORDER BY name
        ) row_data
    ), '[]'::jsonb),
    'product_packaging_rules', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.product_packaging_rules
           WHERE restaurant_id = p_restaurant_id
           ORDER BY product_id, sales_type_id
        ) row_data
    ), '[]'::jsonb),
    'packaging_stock', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.packaging_stock
           WHERE restaurant_id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'payment_methods', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.payment_methods
           WHERE restaurant_id = p_restaurant_id
              OR restaurant_id IS NULL
           ORDER BY display_order, name
        ) row_data
    ), '[]'::jsonb),
    'restaurant_tables', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.restaurant_tables
           WHERE restaurant_id = p_restaurant_id
           ORDER BY name
        ) row_data
    ), '[]'::jsonb),
    'expense_categories', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.expense_categories
           WHERE restaurant_id = p_restaurant_id
              OR restaurant_id IS NULL
           ORDER BY name
        ) row_data
    ), '[]'::jsonb),
    'exchange_rates', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.exchange_rates
           WHERE restaurant_id = p_restaurant_id
           ORDER BY business_date DESC, currency_code
        ) row_data
    ), '[]'::jsonb),
    'cash_register_sessions', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.cash_register_sessions
           WHERE restaurant_id = p_restaurant_id
        ) row_data
    ), '[]'::jsonb),
    'employees', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.employees
           WHERE restaurant_id = p_restaurant_id
             AND is_active = true
           ORDER BY full_name
        ) row_data
    ), '[]'::jsonb),
    'business_rules', COALESCE((
      SELECT jsonb_agg(to_jsonb(row_data))
        FROM (
          SELECT *
            FROM public.business_rules
           WHERE restaurant_id = p_restaurant_id
           ORDER BY key
        ) row_data
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_pull_operational_catalog(
  uuid,
  uuid,
  text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_get_pending_payroll_lines(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_post_payroll_employee(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.pos_pull_operational_catalog(
  uuid,
  uuid,
  text
) TO anon, authenticated;
