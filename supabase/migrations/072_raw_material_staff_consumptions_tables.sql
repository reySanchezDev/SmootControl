INSERT INTO public.permissions (code, name)
VALUES
  ('personal.consumos_materia.ver', 'Ver consumos de materia prima'),
  (
    'personal.consumos_materia.registrar',
    'Registrar consumos de materia prima'
  )
ON CONFLICT (code) DO UPDATE
   SET name = EXCLUDED.name;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
  FROM public.roles role
 CROSS JOIN public.permissions permission
 WHERE role.code = 'admin'
   AND permission.code IN (
     'personal.consumos_materia.ver',
     'personal.consumos_materia.registrar'
   )
ON CONFLICT (role_id, permission_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.employee_raw_material_consumptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id),
  consumed_at timestamptz NOT NULL DEFAULT now(),
  note text,
  total_amount numeric(15, 4) NOT NULL DEFAULT 0,
  payroll_run_id uuid REFERENCES public.payroll_runs(id) ON DELETE SET NULL,
  created_by_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.employee_raw_material_consumption_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consumption_id uuid NOT NULL
    REFERENCES public.employee_raw_material_consumptions(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  product_name text NOT NULL,
  quantity numeric(18, 6) NOT NULL,
  inventory_quantity numeric(18, 6) NOT NULL,
  unit_id uuid REFERENCES public.measurement_units(id),
  unit_name text,
  unit_code text,
  unit_price numeric(15, 4) NOT NULL DEFAULT 0,
  subtotal numeric(15, 4) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS raw_material_consumptions_restaurant_date_idx
  ON public.employee_raw_material_consumptions
  (restaurant_id, consumed_at DESC);

CREATE INDEX IF NOT EXISTS raw_material_consumptions_employee_period_idx
  ON public.employee_raw_material_consumptions
  (restaurant_id, employee_id, consumed_at)
  WHERE payroll_run_id IS NULL;

ALTER TABLE public.employee_raw_material_consumptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_raw_material_consumption_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS raw_material_consumptions_same_restaurant
  ON public.employee_raw_material_consumptions;
CREATE POLICY raw_material_consumptions_same_restaurant
  ON public.employee_raw_material_consumptions
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS raw_material_consumption_lines_same_restaurant
  ON public.employee_raw_material_consumption_lines;
CREATE POLICY raw_material_consumption_lines_same_restaurant
  ON public.employee_raw_material_consumption_lines
  USING (
    EXISTS (
      SELECT 1
        FROM public.employee_raw_material_consumptions consumption
       WHERE consumption.id = consumption_id
         AND public.is_same_restaurant(consumption.restaurant_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
        FROM public.employee_raw_material_consumptions consumption
       WHERE consumption.id = consumption_id
         AND public.is_same_restaurant(consumption.restaurant_id)
    )
  );

ALTER TABLE public.payroll_run_lines
  ADD COLUMN IF NOT EXISTS raw_material_consumption_amount numeric(15, 4)
  NOT NULL DEFAULT 0;

ALTER TABLE public.payroll_payment_receipts
  ADD COLUMN IF NOT EXISTS raw_material_consumption_amount numeric(15, 4)
  NOT NULL DEFAULT 0;
