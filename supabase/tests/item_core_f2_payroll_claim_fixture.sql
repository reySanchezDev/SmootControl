-- Extends the F2 internal-ledger + staff fixtures in one transaction.
-- PostgreSQL disposable fixture only; not a deployed payroll schema.
CREATE TABLE public.payroll_runs (
  id uuid PRIMARY KEY,
  restaurant_id uuid NOT NULL,
  status text NOT NULL
);

INSERT INTO public.payroll_runs VALUES
 ('62000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001','draft'),
 ('62000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001','draft'),
 ('62000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000002','draft');

-- Override fixture-only admin permission stub; real functions require DB
-- profile/role_permissions checks as tested independently by F1.1.
CREATE OR REPLACE FUNCTION public.app_assert_admin_permission(
  p_restaurant_id uuid,p_permission text
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF auth.uid() IS NULL
     OR p_restaurant_id <>
       '00000000-0000-0000-0000-000000000001'::uuid
     OR NOT (
       (p_permission='personal.consumos_materia.registrar'
        AND current_setting('app.can_write_staff',true)='true')
       OR
       (p_permission='planilla.gestionar'
        AND current_setting('app.can_write_payroll',true)='true')
     ) THEN
    RAISE EXCEPTION 'fixture_permission_denied' USING ERRCODE='42501';
  END IF;
END;
$$;

SELECT set_config('app.can_write_payroll','true',true);
