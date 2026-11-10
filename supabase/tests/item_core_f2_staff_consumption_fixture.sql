-- Extends item_core_f2_internal_ledger_fixture.sql, inside one BEGIN.
-- Strictly disposable PostgreSQL. Never execute on the operating database.
ALTER TABLE public.items
  ADD COLUMN name text NOT NULL DEFAULT 'Ingrediente',
  ADD COLUMN base_unit_cost numeric(18,6) NOT NULL DEFAULT 3;

CREATE TABLE public.measurement_units(
  id uuid PRIMARY KEY,
  restaurant_id uuid,
  name text NOT NULL,
  code text NOT NULL,
  is_active boolean NOT NULL
);
CREATE TABLE public.item_units(
  restaurant_id uuid NOT NULL,
  item_id uuid NOT NULL,
  unit_id uuid NOT NULL,
  quantity_in_base numeric(18,8) NOT NULL,
  is_active boolean NOT NULL
);
CREATE TABLE public.item_classifications(
  id uuid PRIMARY KEY,
  restaurant_id uuid NOT NULL,
  code text NOT NULL,
  is_active boolean NOT NULL
);
CREATE TABLE public.item_classification_links(
  restaurant_id uuid NOT NULL,
  item_id uuid NOT NULL,
  classification_id uuid NOT NULL,
  PRIMARY KEY(restaurant_id,item_id,classification_id)
);

CREATE TABLE public.employees(
  id uuid PRIMARY KEY,
  restaurant_id uuid NOT NULL,
  is_active boolean NOT NULL
);
CREATE TABLE public.employee_raw_material_consumptions(
  id uuid PRIMARY KEY,
  restaurant_id uuid NOT NULL,
  employee_id uuid NOT NULL REFERENCES public.employees(id),
  consumed_at timestamptz NOT NULL,
  note text,
  total_amount numeric(15,4) NOT NULL DEFAULT 0,
  payroll_run_id uuid,
  created_by_user_id uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE TABLE public.employee_raw_material_consumption_lines(
  id uuid PRIMARY KEY,
  consumption_id uuid NOT NULL
    REFERENCES public.employee_raw_material_consumptions(id),
  item_id uuid NOT NULL,
  product_name text NOT NULL,
  quantity numeric(18,6) NOT NULL,
  inventory_quantity numeric(18,6) NOT NULL,
  unit_id uuid,
  unit_name text,
  unit_code text,
  unit_price numeric(15,4) NOT NULL,
  subtotal numeric(15,4) NOT NULL
);

CREATE FUNCTION public.app_assert_admin_permission(
  p_restaurant_id uuid,p_permission text
) RETURNS void LANGUAGE plpgsql
AS $$
BEGIN
  IF auth.uid() IS NULL
     OR p_restaurant_id <> '00000000-0000-0000-0000-000000000001'::uuid
     OR p_permission <> 'personal.consumos_materia.registrar'
     OR current_setting('app.can_write_staff',true)<>'true' THEN
    RAISE EXCEPTION 'staff_permission_denied' USING ERRCODE='42501';
  END IF;
END;
$$;

INSERT INTO public.measurement_units VALUES
 ('80000000-0000-0000-0000-000000000001',NULL,'Unidad','unit',true),
 ('80000000-0000-0000-0000-000000000002',NULL,'Caja','box',true);
INSERT INTO public.item_units VALUES
 ('00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '80000000-0000-0000-0000-000000000001',1,true),
 ('00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '80000000-0000-0000-0000-000000000002',12,true);
INSERT INTO public.item_classifications VALUES
 ('90000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001','raw_material',true);
INSERT INTO public.item_classification_links VALUES
 ('00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '90000000-0000-0000-0000-000000000001');
INSERT INTO public.employees VALUES
 ('70000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',true),
 ('70000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000002',true);

SELECT set_config('app.can_write_staff','true',true);
