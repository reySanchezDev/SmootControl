ALTER FUNCTION public.app_reverse_payroll_payment_receipt(uuid, uuid)
RENAME TO app_reverse_payroll_payment_receipt_raw_base_20260724;

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
  result jsonb;
  restored_raw integer := 0;
BEGIN
  SELECT receipt.*
    INTO receipt_row
    FROM public.payroll_payment_receipts receipt
   WHERE receipt.id = p_receipt_id
     AND receipt.restaurant_id = p_restaurant_id;

  IF receipt_row.id IS NULL THEN
    RAISE EXCEPTION 'Pago de planilla no encontrado';
  END IF;

  result := public.app_reverse_payroll_payment_receipt_raw_base_20260724(
    p_restaurant_id,
    p_receipt_id
  );

  IF NOT EXISTS (
    SELECT 1
      FROM public.payroll_payment_receipts receipt
     WHERE receipt.payroll_run_line_id = receipt_row.payroll_run_line_id
  ) THEN
    UPDATE public.employee_raw_material_consumptions
       SET payroll_run_id = NULL,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id
       AND employee_id = receipt_row.employee_id
       AND payroll_run_id = receipt_row.payroll_run_id
       AND consumed_at::date BETWEEN receipt_row.period_start
                                 AND receipt_row.period_end;
    GET DIAGNOSTICS restored_raw = ROW_COUNT;
  END IF;

  RETURN result || jsonb_build_object(
    'restored_raw_material_consumptions',
    restored_raw
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_reverse_payroll_payment_receipt(uuid, uuid)
  TO authenticated;
