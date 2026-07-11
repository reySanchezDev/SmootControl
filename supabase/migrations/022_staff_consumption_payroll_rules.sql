INSERT INTO public.permissions (code, name)
VALUES
  ('personal.gestionar', 'Gestionar personal'),
  ('personal.consumos.ver', 'Ver consumos de personal'),
  ('personal.consumos.registrar', 'Registrar consumos de personal'),
  ('personal.adelantos.gestionar', 'Gestionar adelantos de salario'),
  ('planilla.gestionar', 'Gestionar planilla'),
  ('reglas_negocio.gestionar', 'Gestionar reglas del negocio')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

CREATE TABLE IF NOT EXISTS public.employees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  code text,
  full_name text NOT NULL,
  position_name text,
  base_salary numeric(15, 4) NOT NULL DEFAULT 0 CHECK (base_salary >= 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, code)
);

CREATE TABLE IF NOT EXISTS public.business_rules (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  key text NOT NULL,
  bool_value boolean,
  text_value text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (restaurant_id, key)
);

CREATE TABLE IF NOT EXISTS public.staff_consumption_number_settings (
  restaurant_id uuid PRIMARY KEY REFERENCES public.restaurants(id) ON DELETE CASCADE,
  next_number bigint NOT NULL DEFAULT 1 CHECK (next_number >= 1),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS sale_kind text NOT NULL DEFAULT 'sale',
  ADD COLUMN IF NOT EXISTS employee_id uuid REFERENCES public.employees(id),
  ADD COLUMN IF NOT EXISTS internal_receipt_number bigint,
  ADD COLUMN IF NOT EXISTS payroll_run_id uuid;

ALTER TABLE public.sales
  DROP CONSTRAINT IF EXISTS sales_sale_kind_check;
ALTER TABLE public.sales
  ADD CONSTRAINT sales_sale_kind_check
  CHECK (sale_kind IN ('sale', 'staff_consumption'));

CREATE UNIQUE INDEX IF NOT EXISTS sales_staff_consumption_receipt_idx
  ON public.sales (restaurant_id, internal_receipt_number)
  WHERE sale_kind = 'staff_consumption' AND internal_receipt_number IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.employee_salary_advances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  local_id text UNIQUE,
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id),
  cash_register_session_id uuid REFERENCES public.cash_register_sessions(id),
  amount numeric(15, 4) NOT NULL CHECK (amount > 0),
  balance_amount numeric(15, 4) NOT NULL CHECK (balance_amount >= 0),
  affects_cash boolean NOT NULL DEFAULT false,
  note text,
  created_by_user_id uuid NOT NULL REFERENCES auth.users(id),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'partially_paid', 'paid', 'voided')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.operating_expenses
  ADD COLUMN IF NOT EXISTS expense_kind text NOT NULL DEFAULT 'operational',
  ADD COLUMN IF NOT EXISTS employee_id uuid REFERENCES public.employees(id),
  ADD COLUMN IF NOT EXISTS affects_cash boolean NOT NULL DEFAULT true;

ALTER TABLE public.operating_expenses
  DROP CONSTRAINT IF EXISTS operating_expenses_expense_kind_check;
ALTER TABLE public.operating_expenses
  ADD CONSTRAINT operating_expenses_expense_kind_check
  CHECK (expense_kind IN ('operational', 'salary_advance'));

INSERT INTO public.expense_categories (
  id,
  restaurant_id,
  name,
  description,
  display_order,
  is_active
)
VALUES (
  '33333333-3333-4333-8333-333333333333',
  NULL,
  'Adelantos de salario',
  'Categoria tecnica para adelantos de salario que afectan caja desde POS.',
  900,
  true
)
ON CONFLICT (id) DO UPDATE
   SET name = EXCLUDED.name,
       description = EXCLUDED.description,
       is_active = true,
       updated_at = now();

CREATE OR REPLACE FUNCTION public.pos_sync_operating_expense(
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
  expense_id uuid;
  cash_session_id uuid;
  actor_id uuid;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );

  expense_id := (p_payload ->> 'id')::uuid;
  actor_id := (p_payload ->> 'created_by_user_id')::uuid;
  cash_session_id := NULLIF(
    p_payload ->> 'cash_register_session_id',
    ''
  )::uuid;

  IF cash_session_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
      FROM public.cash_register_sessions
     WHERE id = cash_session_id
       AND restaurant_id = p_restaurant_id
  ) THEN
    SELECT id
      INTO cash_session_id
      FROM public.cash_register_sessions
     WHERE restaurant_id = p_restaurant_id
       AND cashier_user_id = actor_id
       AND status = 'open'
     ORDER BY opened_at DESC
     LIMIT 1;
  END IF;

  INSERT INTO public.operating_expenses (
    id,
    local_id,
    restaurant_id,
    expense_category_id,
    cash_register_session_id,
    created_by_user_id,
    description,
    amount,
    expense_kind,
    employee_id,
    affects_cash,
    sync_status,
    spent_at,
    updated_at
  )
  VALUES (
    expense_id,
    p_payload ->> 'local_id',
    p_restaurant_id,
    (p_payload ->> 'expense_category_id')::uuid,
    cash_session_id,
    actor_id,
    p_payload ->> 'description',
    (p_payload ->> 'amount')::numeric,
    COALESCE(NULLIF(p_payload ->> 'expense_kind', ''), 'operational'),
    NULLIF(p_payload ->> 'employee_id', '')::uuid,
    COALESCE(NULLIF(p_payload ->> 'affects_cash', '')::boolean, true),
    'synced',
    COALESCE(NULLIF(p_payload ->> 'spent_at', '')::timestamptz, now()),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET cash_register_session_id = excluded.cash_register_session_id,
         description = excluded.description,
         amount = excluded.amount,
         expense_kind = excluded.expense_kind,
         employee_id = excluded.employee_id,
         affects_cash = excluded.affects_cash,
         sync_status = 'synced',
         updated_at = now();

  RETURN jsonb_build_object('remote_id', expense_id);
END;
$$;

CREATE TABLE IF NOT EXISTS public.payroll_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'posted', 'voided')),
  created_by_user_id uuid REFERENCES auth.users(id),
  posted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payroll_run_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payroll_run_id uuid NOT NULL REFERENCES public.payroll_runs(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id),
  base_salary numeric(15, 4) NOT NULL DEFAULT 0,
  staff_consumption_amount numeric(15, 4) NOT NULL DEFAULT 0,
  salary_advance_deduction numeric(15, 4) NOT NULL DEFAULT 0,
  net_pay numeric(15, 4) NOT NULL DEFAULT 0,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.business_rules (restaurant_id, key, bool_value)
SELECT id, 'salary_advance_pos_affects_cash', false
  FROM public.restaurants
ON CONFLICT (restaurant_id, key) DO NOTHING;

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

  advance_id := (p_payload ->> 'id')::uuid;
  employee_id_value := (p_payload ->> 'employee_id')::uuid;
  actor_id := COALESCE(NULLIF(p_payload ->> 'created_by_user_id', '')::uuid, auth.uid());
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
    status, created_at, updated_at
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
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET employee_id = excluded.employee_id,
         cash_register_session_id = excluded.cash_register_session_id,
         amount = excluded.amount,
         balance_amount = GREATEST(
           public.employee_salary_advances.balance_amount,
           excluded.balance_amount
         ),
         affects_cash = excluded.affects_cash,
         note = excluded.note,
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
     WHERE id = employee_id_value AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Empleado no pertenece al restaurante';
  END IF;

  IF affects_cash_value AND cash_session_id IS NULL THEN
    RAISE EXCEPTION 'El adelanto requiere caja remota abierta';
  END IF;

  INSERT INTO public.employee_salary_advances (
    id, local_id, restaurant_id, employee_id, cash_register_session_id,
    amount, balance_amount, affects_cash, note, created_by_user_id,
    status, created_at, updated_at
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
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET updated_at = now();

  RETURN jsonb_build_object('remote_id', advance_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_sync_staff_consumption(
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
  sale_payload jsonb;
  item_payload jsonb;
  inventory_payload jsonb;
  packaging_payload jsonb;
  v_sale_id uuid;
  existing_sale_id uuid;
  existing_receipt bigint;
  next_receipt bigint;
  cash_session_id uuid;
  cashier_id uuid;
  current_quantity integer;
  next_quantity integer;
BEGIN
  PERFORM public.assert_pos_device(p_restaurant_id, p_device_id, p_device_secret);

  sale_payload := p_payload -> 'sale';
  v_sale_id := (sale_payload ->> 'id')::uuid;
  cashier_id := (sale_payload ->> 'user_id')::uuid;
  cash_session_id := NULLIF(sale_payload ->> 'cash_register_session_id', '')::uuid;

  IF NOT EXISTS (
    SELECT 1
      FROM public.employees
     WHERE id = (sale_payload ->> 'employee_id')::uuid
       AND restaurant_id = p_restaurant_id
       AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Empleado no activo para consumo de personal';
  END IF;

  SELECT id, internal_receipt_number
    INTO existing_sale_id, existing_receipt
    FROM public.sales
   WHERE restaurant_id = p_restaurant_id
     AND (
       id = v_sale_id
       OR (
         (sale_payload ->> 'local_id') IS NOT NULL
         AND local_id = sale_payload ->> 'local_id'
       )
     )
   LIMIT 1;

  IF existing_sale_id IS NOT NULL THEN
    v_sale_id := existing_sale_id;
    next_receipt := existing_receipt;
  ELSE
    INSERT INTO public.staff_consumption_number_settings (
      restaurant_id, next_number, created_at, updated_at
    )
    VALUES (p_restaurant_id, 1, now(), now())
    ON CONFLICT (restaurant_id) DO NOTHING;

    SELECT next_number
      INTO next_receipt
      FROM public.staff_consumption_number_settings
     WHERE restaurant_id = p_restaurant_id
     FOR UPDATE;

    UPDATE public.staff_consumption_number_settings
       SET next_number = next_receipt + 1,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id;
  END IF;

  INSERT INTO public.sales (
    id,
    local_id,
    restaurant_id,
    cash_register_session_id,
    table_id,
    table_account_id,
    account_name,
    user_id,
    payment_method_id,
    sales_type_id,
    sales_type_name,
    payment_reference,
    invoice_number,
    sale_kind,
    employee_id,
    internal_receipt_number,
    total_amount,
    total_cost,
    gross_profit,
    status,
    sync_status,
    sold_at,
    updated_at
  )
  VALUES (
    v_sale_id,
    sale_payload ->> 'local_id',
    p_restaurant_id,
    cash_session_id,
    NULLIF(sale_payload ->> 'table_id', '')::uuid,
    NULLIF(sale_payload ->> 'table_account_id', '')::uuid,
    sale_payload ->> 'account_name',
    cashier_id,
    (sale_payload ->> 'payment_method_id')::uuid,
    NULLIF(sale_payload ->> 'sales_type_id', '')::uuid,
    sale_payload ->> 'sales_type_name',
    sale_payload ->> 'payment_reference',
    'CP-' || next_receipt,
    'staff_consumption',
    (sale_payload ->> 'employee_id')::uuid,
    next_receipt,
    (sale_payload ->> 'total_amount')::numeric,
    (sale_payload ->> 'total_cost')::numeric,
    (sale_payload ->> 'gross_profit')::numeric,
    COALESCE(sale_payload ->> 'status', 'completed'),
    'synced',
    COALESCE(NULLIF(sale_payload ->> 'sold_at', '')::timestamptz, now()),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET total_amount = excluded.total_amount,
         total_cost = excluded.total_cost,
         gross_profit = excluded.gross_profit,
         sync_status = 'synced',
         updated_at = now();

  FOR item_payload IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_payload -> 'items', '[]'::jsonb))
  LOOP
    INSERT INTO public.sale_items (
      id,
      sale_id,
      product_id,
      table_account_id,
      product_code,
      product_name,
      category_name,
      selected_options_label,
      quantity,
      unit_price,
      unit_cost,
      subtotal,
      gross_profit,
      created_at
    )
    VALUES (
      (item_payload ->> 'id')::uuid,
      v_sale_id,
      NULLIF(item_payload ->> 'product_id', '')::uuid,
      NULLIF(item_payload ->> 'table_account_id', '')::uuid,
      item_payload ->> 'product_code',
      item_payload ->> 'product_name',
      item_payload ->> 'category_name',
      item_payload ->> 'selected_options_label',
      (item_payload ->> 'quantity')::numeric,
      (item_payload ->> 'unit_price')::numeric,
      (item_payload ->> 'unit_cost')::numeric,
      (item_payload ->> 'subtotal')::numeric,
      (item_payload ->> 'gross_profit')::numeric,
      COALESCE(NULLIF(item_payload ->> 'created_at', '')::timestamptz, now())
    )
    ON CONFLICT (id) DO UPDATE
       SET quantity = excluded.quantity,
           unit_price = excluded.unit_price,
           unit_cost = excluded.unit_cost,
           subtotal = excluded.subtotal,
           gross_profit = excluded.gross_profit;
  END LOOP;

  FOR inventory_payload IN
    SELECT value FROM jsonb_array_elements(
      COALESCE(p_payload -> 'inventory_movements', '[]'::jsonb)
    )
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.inventory_movements
       WHERE id = inventory_payload ->> 'id'
    ) THEN
      INSERT INTO public.inventory_stock (
        restaurant_id, product_id, quantity_on_hand, created_at, updated_at
      )
      VALUES (
        p_restaurant_id,
        (inventory_payload ->> 'product_id')::uuid,
        0,
        now(),
        now()
      )
      ON CONFLICT (restaurant_id, product_id) DO NOTHING;

      SELECT quantity_on_hand
        INTO current_quantity
        FROM public.inventory_stock
       WHERE restaurant_id = p_restaurant_id
         AND product_id = (inventory_payload ->> 'product_id')::uuid
       FOR UPDATE;

      next_quantity := current_quantity +
        (inventory_payload ->> 'quantity_delta')::integer;
      IF next_quantity < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente para producto remoto'
          USING ERRCODE = '23514';
      END IF;

      INSERT INTO public.inventory_movements (
        id, restaurant_id, product_id, movement_type, quantity_delta,
        reference_type, reference_id, user_id, notes, created_at
      )
      VALUES (
        inventory_payload ->> 'id',
        p_restaurant_id,
        (inventory_payload ->> 'product_id')::uuid,
        inventory_payload ->> 'movement_type',
        (inventory_payload ->> 'quantity_delta')::integer,
        'staff_consumption',
        v_sale_id,
        inventory_payload ->> 'user_id',
        inventory_payload ->> 'notes',
        COALESCE(NULLIF(inventory_payload ->> 'created_at', '')::timestamptz, now())
      );

      UPDATE public.inventory_stock
         SET quantity_on_hand = next_quantity,
             updated_at = now()
       WHERE restaurant_id = p_restaurant_id
         AND product_id = (inventory_payload ->> 'product_id')::uuid;
    END IF;
  END LOOP;

  FOR packaging_payload IN
    SELECT value FROM jsonb_array_elements(
      COALESCE(p_payload -> 'packaging_movements', '[]'::jsonb)
    )
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.packaging_movements
       WHERE id = packaging_payload ->> 'id'
    ) THEN
      INSERT INTO public.packaging_stock (
        restaurant_id, packaging_item_id, quantity_on_hand, created_at, updated_at
      )
      VALUES (
        p_restaurant_id,
        (packaging_payload ->> 'packaging_item_id')::uuid,
        0,
        now(),
        now()
      )
      ON CONFLICT (restaurant_id, packaging_item_id) DO NOTHING;

      SELECT quantity_on_hand
        INTO current_quantity
        FROM public.packaging_stock
       WHERE restaurant_id = p_restaurant_id
         AND packaging_item_id = (packaging_payload ->> 'packaging_item_id')::uuid
       FOR UPDATE;

      next_quantity := current_quantity +
        (packaging_payload ->> 'quantity_delta')::integer;
      IF next_quantity < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente para empaque remoto'
          USING ERRCODE = '23514';
      END IF;

      INSERT INTO public.packaging_movements (
        id, restaurant_id, packaging_item_id, movement_type, quantity_delta,
        reference_type, reference_id, user_id, notes, unit_cost, created_at
      )
      VALUES (
        packaging_payload ->> 'id',
        p_restaurant_id,
        (packaging_payload ->> 'packaging_item_id')::uuid,
        packaging_payload ->> 'movement_type',
        (packaging_payload ->> 'quantity_delta')::integer,
        'staff_consumption',
        v_sale_id,
        packaging_payload ->> 'user_id',
        packaging_payload ->> 'notes',
        COALESCE((packaging_payload ->> 'unit_cost')::numeric, 0),
        COALESCE(NULLIF(packaging_payload ->> 'created_at', '')::timestamptz, now())
      );

      UPDATE public.packaging_stock
         SET quantity_on_hand = next_quantity,
             updated_at = now()
       WHERE restaurant_id = p_restaurant_id
         AND packaging_item_id = (packaging_payload ->> 'packaging_item_id')::uuid;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'remote_id', v_sale_id,
    'invoice_number', 'CP-' || next_receipt,
    'internal_receipt_number', next_receipt
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_register_salary_advance(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.pos_sync_salary_advance(uuid, uuid, text, jsonb)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pos_sync_staff_consumption(uuid, uuid, text, jsonb)
  TO anon, authenticated;

ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_consumption_number_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_salary_advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_run_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS employees_same_restaurant ON public.employees;
CREATE POLICY employees_same_restaurant ON public.employees
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS business_rules_same_restaurant ON public.business_rules;
CREATE POLICY business_rules_same_restaurant ON public.business_rules
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS staff_consumption_numbers_same_restaurant
  ON public.staff_consumption_number_settings;
CREATE POLICY staff_consumption_numbers_same_restaurant
  ON public.staff_consumption_number_settings
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS salary_advances_same_restaurant
  ON public.employee_salary_advances;
CREATE POLICY salary_advances_same_restaurant
  ON public.employee_salary_advances
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS payroll_runs_same_restaurant ON public.payroll_runs;
CREATE POLICY payroll_runs_same_restaurant ON public.payroll_runs
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS payroll_lines_same_restaurant ON public.payroll_run_lines;
CREATE POLICY payroll_lines_same_restaurant ON public.payroll_run_lines
  USING (
    EXISTS (
      SELECT 1 FROM public.payroll_runs run
       WHERE run.id = payroll_run_id
         AND public.is_same_restaurant(run.restaurant_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.payroll_runs run
       WHERE run.id = payroll_run_id
         AND public.is_same_restaurant(run.restaurant_id)
    )
  );
