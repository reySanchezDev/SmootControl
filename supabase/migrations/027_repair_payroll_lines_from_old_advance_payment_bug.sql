UPDATE public.payroll_run_lines
   SET paid_amount = net_pay,
       balance_amount = 0,
       details = details || jsonb_build_object(
         'repaired_by',
         '027_repair_payroll_lines_from_old_advance_payment_bug',
         'repaired_at',
         now()
       )
 WHERE balance_amount > 0
   AND salary_advance_deduction > 0
   AND paid_amount + salary_advance_deduction >= net_pay;

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
         AND (
           (
             run_line.balance_amount > 0
             AND run_line.paid_amount +
               run_line.salary_advance_deduction < run_line.net_pay
           )
           OR run.period_end >= CURRENT_DATE - INTERVAL '45 days'
         )
       ORDER BY run.period_start, employee.full_name
    ) row_data;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_get_pending_payroll_lines(uuid)
  TO authenticated;
