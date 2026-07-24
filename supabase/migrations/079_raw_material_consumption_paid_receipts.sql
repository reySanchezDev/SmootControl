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
        'overtime_amount', receipt.overtime_amount,
        'staff_consumption_amount', receipt.staff_consumption_amount,
        'raw_material_consumption_amount',
          COALESCE(receipt.raw_material_consumption_amount, 0),
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
      JOIN public.employees employee ON employee.id = receipt.employee_id
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

GRANT EXECUTE ON FUNCTION
  public.app_get_paid_payroll_receipts(uuid, date, date, text)
  TO authenticated;
