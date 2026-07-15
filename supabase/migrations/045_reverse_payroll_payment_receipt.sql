CREATE OR REPLACE FUNCTION public.app_reverse_payroll_payment_receipt(
  p_restaurant_id uuid,
  p_receipt_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  receipt_row record;
  remaining_receipts integer;
  restored_advances integer := 0;
  restored_consumptions integer := 0;
  deleted_lines integer := 0;
  deleted_runs integer := 0;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'planilla.gestionar'
  );

  SELECT *
    INTO receipt_row
    FROM public.payroll_payment_receipts
   WHERE id = p_receipt_id
     AND restaurant_id = p_restaurant_id
   FOR UPDATE;

  IF receipt_row.id IS NULL THEN
    RAISE EXCEPTION 'Pago de planilla no encontrado';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.payroll_payment_receipts newer
     WHERE newer.payroll_run_line_id = receipt_row.payroll_run_line_id
       AND newer.paid_at > receipt_row.paid_at
  ) THEN
    RAISE EXCEPTION 'Primero elimina los pagos posteriores de esta planilla';
  END IF;

  SELECT count(*)
    INTO remaining_receipts
    FROM public.payroll_payment_receipts
   WHERE payroll_run_line_id = receipt_row.payroll_run_line_id
     AND id <> receipt_row.id;

  DELETE FROM public.payroll_payment_receipts
   WHERE id = receipt_row.id;

  IF remaining_receipts > 0 THEN
    UPDATE public.payroll_run_lines
       SET paid_amount = GREATEST(
             paid_amount - receipt_row.payment_amount,
             0
           ),
           balance_amount = balance_amount + receipt_row.payment_amount,
           details = details || jsonb_build_object(
             'last_reversed_receipt_id',
             receipt_row.id,
             'last_reversed_at',
             now()
           )
     WHERE id = receipt_row.payroll_run_line_id;

    RETURN jsonb_build_object(
      'deleted_receipts', 1,
      'restored_advances', 0,
      'restored_consumptions', 0,
      'deleted_lines', 0,
      'deleted_runs', 0
    );
  END IF;

  WITH advance_rows AS (
    SELECT (item ->> 'advance_id')::uuid AS advance_id,
           COALESCE((item ->> 'applied_amount')::numeric, 0) AS amount
      FROM jsonb_array_elements(
        COALESCE(receipt_row.details -> 'salary_advances', '[]'::jsonb)
      ) item
  ),
  restored AS (
    UPDATE public.employee_salary_advances advance
       SET balance_amount = advance.balance_amount + advance_rows.amount,
           status = CASE
             WHEN advance.balance_amount + advance_rows.amount >= advance.amount
               THEN 'pending'
             WHEN advance.balance_amount + advance_rows.amount <= 0
               THEN 'paid'
             ELSE 'partially_paid'
           END,
           updated_at = now()
      FROM advance_rows
     WHERE advance.id = advance_rows.advance_id
       AND advance.restaurant_id = p_restaurant_id
    RETURNING advance.id
  )
  SELECT count(*) INTO restored_advances FROM restored;

  UPDATE public.sales
     SET payroll_run_id = NULL,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
     AND employee_id = receipt_row.employee_id
     AND sale_kind = 'staff_consumption'
     AND payroll_run_id = receipt_row.payroll_run_id;
  GET DIAGNOSTICS restored_consumptions = ROW_COUNT;

  DELETE FROM public.payroll_run_lines
   WHERE id = receipt_row.payroll_run_line_id
     AND payroll_run_id = receipt_row.payroll_run_id;
  GET DIAGNOSTICS deleted_lines = ROW_COUNT;

  DELETE FROM public.payroll_runs run
   WHERE run.id = receipt_row.payroll_run_id
     AND NOT EXISTS (
       SELECT 1
         FROM public.payroll_run_lines line
        WHERE line.payroll_run_id = run.id
     );
  GET DIAGNOSTICS deleted_runs = ROW_COUNT;

  RETURN jsonb_build_object(
    'deleted_receipts', 1,
    'restored_advances', restored_advances,
    'restored_consumptions', restored_consumptions,
    'deleted_lines', deleted_lines,
    'deleted_runs', deleted_runs
  );
END;
$$;

REVOKE ALL ON FUNCTION public.app_reverse_payroll_payment_receipt(uuid, uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_reverse_payroll_payment_receipt(uuid, uuid)
  TO authenticated;
