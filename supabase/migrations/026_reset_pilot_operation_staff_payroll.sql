CREATE OR REPLACE FUNCTION public.reset_pilot_operation(
  p_restaurant_id uuid,
  p_confirmation text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor_id uuid := auth.uid();
  deleted_sale_voids integer := 0;
  deleted_sale_items integer := 0;
  deleted_sales integer := 0;
  deleted_expenses integer := 0;
  deleted_table_accounts integer := 0;
  deleted_cash_sessions integer := 0;
  deleted_inventory_movements integer := 0;
  deleted_packaging_movements integer := 0;
  deleted_salary_advances integer := 0;
  deleted_payroll_lines integer := 0;
  deleted_payroll_runs integer := 0;
  deleted_sync_logs integer := 0;
  reset_inventory_stock integer := 0;
  reset_packaging_stock integer := 0;
  reset_invoice_settings integer := 0;
  reset_staff_consumption_settings integer := 0;
  total_rows integer := 0;
BEGIN
  IF p_confirmation <> 'REINICIAR PRODUCCION' THEN
    RAISE EXCEPTION 'Confirmacion invalida para reiniciar operacion'
      USING ERRCODE = '22023';
  END IF;

  IF actor_id IS NULL THEN
    RAISE EXCEPTION 'Se requiere sesion administrativa remota'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.is_same_restaurant(p_restaurant_id) THEN
    RAISE EXCEPTION 'No autorizado para este restaurante'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM public.profiles profile
      JOIN public.roles role
        ON role.id = profile.role_id
      JOIN public.role_permissions role_permission
        ON role_permission.role_id = role.id
      JOIN public.permissions permission
        ON permission.id = role_permission.permission_id
     WHERE profile.id = actor_id
       AND profile.restaurant_id = p_restaurant_id
       AND profile.is_active = true
       AND permission.code = 'sistema.reiniciar_operacion'
  ) THEN
    RAISE EXCEPTION 'No autorizado para reiniciar operacion piloto'
      USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.payroll_run_lines run_line
  USING public.payroll_runs run
   WHERE run_line.payroll_run_id = run.id
     AND run.restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_payroll_lines = ROW_COUNT;

  DELETE FROM public.payroll_runs
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_payroll_runs = ROW_COUNT;

  DELETE FROM public.employee_salary_advances
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_salary_advances = ROW_COUNT;

  DELETE FROM public.sale_voids
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_sale_voids = ROW_COUNT;

  DELETE FROM public.sale_items item
  USING public.sales sale
   WHERE item.sale_id = sale.id
     AND sale.restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_sale_items = ROW_COUNT;

  DELETE FROM public.sales
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_sales = ROW_COUNT;

  DELETE FROM public.operating_expenses
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_expenses = ROW_COUNT;

  DELETE FROM public.table_accounts
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_table_accounts = ROW_COUNT;

  DELETE FROM public.cash_register_sessions
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_cash_sessions = ROW_COUNT;

  DELETE FROM public.inventory_movements
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_inventory_movements = ROW_COUNT;

  DELETE FROM public.packaging_movements
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_packaging_movements = ROW_COUNT;

  UPDATE public.inventory_stock
     SET quantity_on_hand = 0,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS reset_inventory_stock = ROW_COUNT;

  UPDATE public.packaging_stock
     SET quantity_on_hand = 0,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS reset_packaging_stock = ROW_COUNT;

  UPDATE public.invoice_number_settings
     SET next_number = initial_number,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS reset_invoice_settings = ROW_COUNT;

  INSERT INTO public.staff_consumption_number_settings (
    restaurant_id,
    next_number,
    updated_at
  )
  VALUES (p_restaurant_id, 1, now())
  ON CONFLICT (restaurant_id) DO UPDATE
     SET next_number = 1,
         updated_at = now();
  GET DIAGNOSTICS reset_staff_consumption_settings = ROW_COUNT;

  DELETE FROM public.sync_logs
   WHERE restaurant_id = p_restaurant_id;
  GET DIAGNOSTICS deleted_sync_logs = ROW_COUNT;

  total_rows :=
    deleted_sale_voids +
    deleted_sale_items +
    deleted_sales +
    deleted_expenses +
    deleted_table_accounts +
    deleted_cash_sessions +
    deleted_inventory_movements +
    deleted_packaging_movements +
    deleted_salary_advances +
    deleted_payroll_lines +
    deleted_payroll_runs +
    deleted_sync_logs +
    reset_inventory_stock +
    reset_packaging_stock +
    reset_invoice_settings +
    reset_staff_consumption_settings;

  INSERT INTO public.audit_logs (
    restaurant_id,
    actor_user_id,
    action,
    entity_name,
    entity_id,
    details
  )
  VALUES (
    p_restaurant_id,
    actor_id,
    'system.pilot_reset',
    'restaurants',
    p_restaurant_id,
    jsonb_build_object(
      'deleted_sale_voids', deleted_sale_voids,
      'deleted_sale_items', deleted_sale_items,
      'deleted_sales', deleted_sales,
      'deleted_expenses', deleted_expenses,
      'deleted_table_accounts', deleted_table_accounts,
      'deleted_cash_sessions', deleted_cash_sessions,
      'deleted_inventory_movements', deleted_inventory_movements,
      'deleted_packaging_movements', deleted_packaging_movements,
      'deleted_salary_advances', deleted_salary_advances,
      'deleted_payroll_lines', deleted_payroll_lines,
      'deleted_payroll_runs', deleted_payroll_runs,
      'deleted_sync_logs', deleted_sync_logs,
      'reset_inventory_stock', reset_inventory_stock,
      'reset_packaging_stock', reset_packaging_stock,
      'reset_invoice_settings', reset_invoice_settings,
      'reset_staff_consumption_settings',
      reset_staff_consumption_settings,
      'total_rows', total_rows
    )
  );

  RETURN jsonb_build_object(
    'deleted_sale_voids', deleted_sale_voids,
    'deleted_sale_items', deleted_sale_items,
    'deleted_sales', deleted_sales,
    'deleted_expenses', deleted_expenses,
    'deleted_table_accounts', deleted_table_accounts,
    'deleted_cash_sessions', deleted_cash_sessions,
    'deleted_inventory_movements', deleted_inventory_movements,
    'deleted_packaging_movements', deleted_packaging_movements,
    'deleted_salary_advances', deleted_salary_advances,
    'deleted_payroll_lines', deleted_payroll_lines,
    'deleted_payroll_runs', deleted_payroll_runs,
    'deleted_sync_logs', deleted_sync_logs,
    'reset_inventory_stock', reset_inventory_stock,
    'reset_packaging_stock', reset_packaging_stock,
    'reset_invoice_settings', reset_invoice_settings,
    'reset_staff_consumption_settings', reset_staff_consumption_settings,
    'total_rows', total_rows
  );
END;
$$;

COMMENT ON FUNCTION public.reset_pilot_operation(uuid, text) IS
  'Deletes pilot operational data, staff payroll activity and resets inventory/packaging stock while preserving catalogs.';

REVOKE ALL ON FUNCTION public.reset_pilot_operation(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reset_pilot_operation(uuid, text)
  TO authenticated;
