INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
  FROM public.roles role
  JOIN public.permissions permission
    ON permission.code IN (
      'personal.gestionar',
      'personal.consumos.ver',
      'personal.consumos.registrar',
      'personal.adelantos.gestionar',
      'planilla.gestionar',
      'reglas_negocio.gestionar'
    )
 WHERE role.code = 'admin'
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.employee_positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  name text NOT NULL,
  display_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, name)
);

CREATE TABLE IF NOT EXISTS public.employee_number_settings (
  restaurant_id uuid PRIMARY KEY REFERENCES public.restaurants(id) ON DELETE CASCADE,
  next_number bigint NOT NULL DEFAULT 1 CHECK (next_number >= 1),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS employee_number bigint,
  ADD COLUMN IF NOT EXISTS position_id uuid REFERENCES public.employee_positions(id);

CREATE UNIQUE INDEX IF NOT EXISTS employees_restaurant_number_idx
  ON public.employees (restaurant_id, employee_number)
  WHERE employee_number IS NOT NULL;

WITH numbered AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY restaurant_id
           ORDER BY created_at, id
         ) AS next_number
    FROM public.employees
   WHERE employee_number IS NULL
)
UPDATE public.employees employee
   SET employee_number = numbered.next_number,
       code = COALESCE(employee.code, numbered.next_number::text),
       updated_at = now()
  FROM numbered
 WHERE employee.id = numbered.id;

INSERT INTO public.employee_number_settings (restaurant_id, next_number)
SELECT restaurant.id,
       COALESCE(MAX(employee.employee_number), 0) + 1
  FROM public.restaurants restaurant
  LEFT JOIN public.employees employee
    ON employee.restaurant_id = restaurant.id
 GROUP BY restaurant.id
ON CONFLICT (restaurant_id) DO UPDATE
   SET next_number = GREATEST(
         public.employee_number_settings.next_number,
         excluded.next_number
       ),
       updated_at = now();

ALTER TABLE public.employee_salary_advances
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz;

UPDATE public.employee_salary_advances
   SET delivered_at = created_at
 WHERE delivered_at IS NULL;

ALTER TABLE public.employee_salary_advances
  ALTER COLUMN delivered_at SET DEFAULT now(),
  ALTER COLUMN delivered_at SET NOT NULL;

ALTER TABLE public.employee_salary_advances
  DROP CONSTRAINT IF EXISTS employee_salary_advances_created_by_user_id_fkey;

ALTER TABLE public.employee_salary_advances
  ADD CONSTRAINT employee_salary_advances_created_by_user_id_fkey
  FOREIGN KEY (created_by_user_id) REFERENCES public.profiles(id);

ALTER TABLE public.payroll_run_lines
  DROP CONSTRAINT IF EXISTS payroll_run_lines_run_employee_key;

ALTER TABLE public.payroll_run_lines
  ADD CONSTRAINT payroll_run_lines_run_employee_key
  UNIQUE (payroll_run_id, employee_id);

CREATE UNIQUE INDEX IF NOT EXISTS payroll_runs_period_active_idx
  ON public.payroll_runs (restaurant_id, period_start, period_end)
  WHERE status <> 'voided';

DROP POLICY IF EXISTS employee_positions_same_restaurant
  ON public.employee_positions;
CREATE POLICY employee_positions_same_restaurant
  ON public.employee_positions
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

ALTER TABLE public.employee_positions ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.app_save_employee_position(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  position_id uuid;
  result_row jsonb;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'personal.gestionar'
  );

  position_id := NULLIF(btrim(COALESCE(p_payload ->> 'id', '')), '')::uuid;
  IF position_id IS NULL THEN
    position_id := gen_random_uuid();
  END IF;

  INSERT INTO public.employee_positions (
    id,
    restaurant_id,
    name,
    display_order,
    is_active,
    updated_at
  )
  VALUES (
    position_id,
    p_restaurant_id,
    NULLIF(btrim(p_payload ->> 'name'), ''),
    COALESCE((p_payload ->> 'display_order')::integer, 0),
    COALESCE((p_payload ->> 'is_active')::boolean, true),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET name = excluded.name,
         display_order = excluded.display_order,
         is_active = excluded.is_active,
         updated_at = now();

  SELECT to_jsonb(position_row)
    INTO result_row
    FROM public.employee_positions position_row
   WHERE position_row.id = position_id;

  RETURN result_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_save_employee(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  employee_id uuid;
  employee_number_value bigint;
  position_id_value uuid;
  result_row jsonb;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'personal.gestionar'
  );

  employee_id := NULLIF(btrim(COALESCE(p_payload ->> 'id', '')), '')::uuid;
  position_id_value := NULLIF(
    btrim(COALESCE(p_payload ->> 'position_id', '')),
    ''
  )::uuid;

  IF position_id_value IS NOT NULL AND NOT EXISTS (
    SELECT 1
      FROM public.employee_positions
     WHERE id = position_id_value
       AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Puesto no pertenece al restaurante';
  END IF;

  IF employee_id IS NULL THEN
    INSERT INTO public.employee_number_settings (restaurant_id, next_number)
    VALUES (p_restaurant_id, 1)
    ON CONFLICT (restaurant_id) DO NOTHING;

    SELECT next_number
      INTO employee_number_value
      FROM public.employee_number_settings
     WHERE restaurant_id = p_restaurant_id
     FOR UPDATE;

    UPDATE public.employee_number_settings
       SET next_number = employee_number_value + 1,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id;

    employee_id := gen_random_uuid();

    INSERT INTO public.employees (
      id,
      restaurant_id,
      employee_number,
      code,
      full_name,
      position_id,
      position_name,
      base_salary,
      is_active,
      updated_at
    )
    VALUES (
      employee_id,
      p_restaurant_id,
      employee_number_value,
      employee_number_value::text,
      NULLIF(btrim(p_payload ->> 'full_name'), ''),
      position_id_value,
      (
        SELECT name
          FROM public.employee_positions
         WHERE id = position_id_value
      ),
      COALESCE((p_payload ->> 'base_salary')::numeric, 0),
      COALESCE((p_payload ->> 'is_active')::boolean, true),
      now()
    );
  ELSE
    UPDATE public.employees
       SET full_name = NULLIF(btrim(p_payload ->> 'full_name'), ''),
           position_id = position_id_value,
           position_name = (
             SELECT name
               FROM public.employee_positions
              WHERE id = position_id_value
           ),
           base_salary = COALESCE((p_payload ->> 'base_salary')::numeric, 0),
           is_active = COALESCE((p_payload ->> 'is_active')::boolean, true),
           updated_at = now()
     WHERE id = employee_id
       AND restaurant_id = p_restaurant_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Empleado no pertenece al restaurante';
    END IF;
  END IF;

  SELECT to_jsonb(employee_row)
    INTO result_row
    FROM public.employees employee_row
   WHERE employee_row.id = employee_id;

  RETURN result_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_register_salary_advance(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  advance_id uuid;
  employee_id_value uuid;
  actor_id uuid;
  amount_value numeric;
  cash_session_id uuid;
  affects_cash_value boolean;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'personal.adelantos.gestionar'
  );

  advance_id := COALESCE(
    NULLIF(btrim(COALESCE(p_payload ->> 'id', '')), '')::uuid,
    gen_random_uuid()
  );
  employee_id_value := (p_payload ->> 'employee_id')::uuid;
  actor_id := COALESCE(
    NULLIF(p_payload ->> 'created_by_user_id', '')::uuid,
    auth.uid()
  );
  amount_value := (p_payload ->> 'amount')::numeric;
  cash_session_id := NULLIF(p_payload ->> 'cash_register_session_id', '')::uuid;
  affects_cash_value := COALESCE((p_payload ->> 'affects_cash')::boolean, false);

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Empleado no pertenece al restaurante';
  END IF;

  INSERT INTO public.employee_salary_advances (
    id, local_id, restaurant_id, employee_id, cash_register_session_id,
    amount, balance_amount, affects_cash, note, created_by_user_id,
    status, created_at, delivered_at, updated_at
  )
  VALUES (
    advance_id,
    p_payload ->> 'local_id',
    p_restaurant_id,
    employee_id_value,
    cash_session_id,
    amount_value,
    amount_value,
    affects_cash_value,
    p_payload ->> 'note',
    actor_id,
    COALESCE(NULLIF(p_payload ->> 'status', ''), 'pending'),
    COALESCE(NULLIF(p_payload ->> 'created_at', '')::timestamptz, now()),
    COALESCE(NULLIF(p_payload ->> 'delivered_at', '')::timestamptz, now()),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET employee_id = excluded.employee_id,
         cash_register_session_id = excluded.cash_register_session_id,
         amount = excluded.amount,
         balance_amount = LEAST(
           public.employee_salary_advances.balance_amount,
           excluded.balance_amount
         ),
         affects_cash = excluded.affects_cash,
         note = excluded.note,
         delivered_at = excluded.delivered_at,
         updated_at = now();

  RETURN jsonb_build_object('remote_id', advance_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_sync_salary_advance(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  advance_id uuid;
  employee_id_value uuid;
  actor_id uuid;
  amount_value numeric;
  cash_session_id uuid;
  affects_cash_value boolean;
BEGIN
  PERFORM public.assert_pos_device(p_restaurant_id, p_device_id, p_device_secret);

  advance_id := (p_payload ->> 'id')::uuid;
  employee_id_value := (p_payload ->> 'employee_id')::uuid;
  actor_id := (p_payload ->> 'created_by_user_id')::uuid;
  amount_value := (p_payload ->> 'amount')::numeric;
  cash_session_id := NULLIF(p_payload ->> 'cash_register_session_id', '')::uuid;
  affects_cash_value := COALESCE((p_payload ->> 'affects_cash')::boolean, false);

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value
       AND restaurant_id = p_restaurant_id
       AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Empleado no pertenece al restaurante';
  END IF;

  IF affects_cash_value AND cash_session_id IS NULL THEN
    RAISE EXCEPTION 'Adelanto de caja sin sesion de caja';
  END IF;

  INSERT INTO public.employee_salary_advances (
    id, local_id, restaurant_id, employee_id, cash_register_session_id,
    amount, balance_amount, affects_cash, note, created_by_user_id,
    status, created_at, delivered_at, updated_at
  )
  VALUES (
    advance_id,
    p_payload ->> 'local_id',
    p_restaurant_id,
    employee_id_value,
    cash_session_id,
    amount_value,
    amount_value,
    affects_cash_value,
    p_payload ->> 'note',
    actor_id,
    'pending',
    COALESCE(NULLIF(p_payload ->> 'created_at', '')::timestamptz, now()),
    COALESCE(NULLIF(p_payload ->> 'delivered_at', '')::timestamptz, now()),
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('remote_id', advance_id);
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
  remaining_deduction numeric;
  advance_row record;
  deduction_for_row numeric;
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

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Empleado no pertenece al restaurante';
  END IF;

  SELECT COALESCE(SUM(total_amount), 0)
    INTO consumption_value
    FROM public.sales
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = employee_id_value
     AND sale_kind = 'staff_consumption'
     AND payroll_run_id IS NULL
     AND sold_at::date BETWEEN period_start_value AND period_end_value;

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

  INSERT INTO public.payroll_run_lines (
    payroll_run_id,
    employee_id,
    base_salary,
    staff_consumption_amount,
    salary_advance_deduction,
    net_pay,
    details
  )
  VALUES (
    payroll_run_id_value,
    employee_id_value,
    base_salary_value,
    consumption_value,
    requested_advance_deduction,
    base_salary_value - consumption_value - requested_advance_deduction,
    jsonb_build_object('posted_by', auth.uid(), 'posted_at', now())
  )
  ON CONFLICT (payroll_run_id, employee_id) DO UPDATE
     SET base_salary = excluded.base_salary,
         staff_consumption_amount = excluded.staff_consumption_amount,
         salary_advance_deduction = excluded.salary_advance_deduction,
         net_pay = excluded.net_pay,
         details = excluded.details
  RETURNING id INTO line_id_value;

  RETURN jsonb_build_object(
    'payroll_run_id', payroll_run_id_value,
    'payroll_line_id', line_id_value
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_save_employee_position(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_save_employee(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_post_payroll_employee(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_register_salary_advance(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.pos_sync_salary_advance(uuid, uuid, text, jsonb)
  TO authenticated, anon;
