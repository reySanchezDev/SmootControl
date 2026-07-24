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
      SELECT line.payroll_run_id,
             line.employee_id,
             employee.full_name AS employee_name,
             run.period_start,
             run.period_end,
             (CASE WHEN EXTRACT(DAY FROM run.period_start) <= 15
               THEN 'Primera quincena' ELSE 'Segunda quincena' END) ||
             ' de ' || (ARRAY[
               'Enero','Febrero','Marzo','Abril','Mayo','Junio',
               'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
             ])[EXTRACT(MONTH FROM run.period_start)::integer] ||
             ' ' || EXTRACT(YEAR FROM run.period_start)::integer AS period_label,
             line.base_salary,
             line.staff_consumption_amount,
             line.raw_material_consumption_amount,
             line.salary_advance_deduction,
             COALESCE((line.details ->> 'overtime_amount')::numeric, 0)
               AS overtime_amount,
             line.net_pay,
             line.paid_amount,
             line.balance_amount
      FROM public.payroll_run_lines line
      JOIN public.payroll_runs run ON run.id = line.payroll_run_id
      JOIN public.employees employee ON employee.id = line.employee_id
      WHERE run.restaurant_id = p_restaurant_id
        AND run.status <> 'voided'
        AND (
          (line.balance_amount > 0
           AND line.paid_amount + line.salary_advance_deduction < line.net_pay)
          OR run.period_end >= CURRENT_DATE - INTERVAL '45 days'
        )
    ) row_data
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_get_employee_raw_material_payroll_total(
  p_restaurant_id uuid,
  p_employee_id uuid,
  p_start date,
  p_end date
)
RETURNS numeric
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(total_amount), 0)
  FROM public.employee_raw_material_consumptions
  WHERE restaurant_id = p_restaurant_id
    AND employee_id = p_employee_id
    AND payroll_run_id IS NULL
    AND consumed_at::date BETWEEN p_start AND p_end
$$;

CREATE OR REPLACE FUNCTION public.app_mark_raw_material_consumptions_paid(
  p_restaurant_id uuid,
  p_employee_id uuid,
  p_start date,
  p_end date,
  p_payroll_run_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  details jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'consumption_id', id,
    'date', consumed_at,
    'amount', total_amount,
    'note', note
  ) ORDER BY consumed_at), '[]'::jsonb)
  INTO details
  FROM public.employee_raw_material_consumptions
  WHERE restaurant_id = p_restaurant_id
    AND employee_id = p_employee_id
    AND payroll_run_id IS NULL
    AND consumed_at::date BETWEEN p_start AND p_end;

  UPDATE public.employee_raw_material_consumptions
  SET payroll_run_id = p_payroll_run_id,
      updated_at = now()
  WHERE restaurant_id = p_restaurant_id
    AND employee_id = p_employee_id
    AND payroll_run_id IS NULL
    AND consumed_at::date BETWEEN p_start AND p_end;

  RETURN details;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_get_pending_payroll_lines(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_get_employee_raw_material_payroll_total(
  uuid, uuid, date, date
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_mark_raw_material_consumptions_paid(
  uuid, uuid, date, date, uuid
) TO authenticated;
