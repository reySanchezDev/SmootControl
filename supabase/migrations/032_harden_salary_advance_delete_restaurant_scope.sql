CREATE OR REPLACE FUNCTION public.app_delete_salary_advance(
  p_restaurant_id uuid,
  p_advance_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_advances integer := 0;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'personal.adelantos.gestionar'
  );

  IF NOT EXISTS (
    SELECT 1
      FROM public.employee_salary_advances
     WHERE id = p_advance_id
       AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Adelanto no encontrado';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.employee_salary_advances
     WHERE id = p_advance_id
       AND restaurant_id = p_restaurant_id
       AND status IN ('partially_paid', 'paid')
  ) THEN
    RAISE EXCEPTION 'No se puede eliminar un adelanto con abonos de planilla';
  END IF;

  UPDATE public.payroll_run_lines line
     SET details = details - 'salary_advance_id' - 'advance_id'
    FROM public.payroll_runs run
   WHERE run.id = line.payroll_run_id
     AND run.restaurant_id = p_restaurant_id
     AND (
       line.details ->> 'salary_advance_id' = p_advance_id::text
       OR line.details ->> 'advance_id' = p_advance_id::text
     );

  DELETE FROM public.employee_salary_advances
   WHERE id = p_advance_id
     AND restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_advances = ROW_COUNT;

  RETURN jsonb_build_object(
    'deleted_advance_id', p_advance_id,
    'deleted_advances', deleted_advances
  );
END;
$$;

REVOKE ALL ON FUNCTION public.app_delete_salary_advance(uuid, uuid)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_delete_salary_advance(uuid, uuid)
  TO authenticated;
