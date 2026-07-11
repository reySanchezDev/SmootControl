CREATE TABLE IF NOT EXISTS public.pilot_cleanup_markers (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  scope text NOT NULL,
  cleaned_at timestamptz NOT NULL DEFAULT now(),
  actor_user_id uuid REFERENCES auth.users(id),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (restaurant_id, scope)
);

ALTER TABLE public.pilot_cleanup_markers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pilot_cleanup_markers_same_restaurant
  ON public.pilot_cleanup_markers;
CREATE POLICY pilot_cleanup_markers_same_restaurant
  ON public.pilot_cleanup_markers
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

CREATE OR REPLACE FUNCTION public.reset_pilot_operation_scope(
  p_restaurant_id uuid,
  p_confirmation text,
  p_scope text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor_id uuid := auth.uid();
  normalized_scope text := lower(trim(p_scope));
  expected_confirmation text;
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
  reset_invoice_settings integer := 0;
  reset_staff_consumption_settings integer := 0;
  total_rows integer := 0;
  details jsonb;
  stock_row record;
BEGIN
  IF normalized_scope NOT IN (
    'sales',
    'expenses',
    'salary_advances',
    'payroll',
    'staff_consumptions',
    'staff_operations'
  ) THEN
    RAISE EXCEPTION 'Alcance de limpieza no soportado: %', p_scope
      USING ERRCODE = '22023';
  END IF;

  expected_confirmation := CASE normalized_scope
    WHEN 'sales' THEN 'BORRAR VENTAS'
    WHEN 'expenses' THEN 'BORRAR GASTOS'
    WHEN 'salary_advances' THEN 'BORRAR ADELANTOS'
    WHEN 'payroll' THEN 'BORRAR PLANILLA'
    WHEN 'staff_consumptions' THEN 'BORRAR CONSUMOS'
    WHEN 'staff_operations' THEN 'BORRAR PERSONAL OPERATIVO'
  END;

  IF p_confirmation <> expected_confirmation THEN
    RAISE EXCEPTION 'Confirmacion invalida para limpieza %', normalized_scope
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
    RAISE EXCEPTION 'No autorizado para limpiar datos de piloto'
      USING ERRCODE = '42501';
  END IF;

  IF normalized_scope IN ('staff_consumptions', 'salary_advances')
     AND EXISTS (
       SELECT 1
         FROM public.payroll_runs run
         JOIN public.payroll_run_lines line
           ON line.payroll_run_id = run.id
        WHERE run.restaurant_id = p_restaurant_id
          AND run.status <> 'voided'
     )
  THEN
    RAISE EXCEPTION 'Primero debes limpiar planilla para borrar este alcance'
      USING ERRCODE = '23503';
  END IF;

  IF normalized_scope IN ('payroll', 'staff_operations') THEN
    UPDATE public.sales sale
       SET payroll_run_id = NULL,
           updated_at = now()
      FROM public.payroll_runs run
     WHERE sale.payroll_run_id = run.id
       AND run.restaurant_id = p_restaurant_id
       AND sale.restaurant_id = p_restaurant_id
       AND sale.sale_kind = 'staff_consumption';

    DELETE FROM public.payroll_run_lines line
    USING public.payroll_runs run
     WHERE line.payroll_run_id = run.id
       AND run.restaurant_id = p_restaurant_id;
    GET DIAGNOSTICS deleted_payroll_lines = ROW_COUNT;

    DELETE FROM public.payroll_runs
     WHERE restaurant_id = p_restaurant_id;
    GET DIAGNOSTICS deleted_payroll_runs = ROW_COUNT;
  END IF;

  IF normalized_scope IN ('staff_consumptions', 'staff_operations') THEN
    FOR stock_row IN
      SELECT product_id, SUM(quantity_delta) AS quantity_delta
        FROM public.inventory_movements
       WHERE restaurant_id = p_restaurant_id
         AND reference_type = 'staff_consumption'
       GROUP BY product_id
    LOOP
      UPDATE public.inventory_stock
         SET quantity_on_hand = GREATEST(
               quantity_on_hand - stock_row.quantity_delta,
               0
             ),
             updated_at = now()
       WHERE restaurant_id = p_restaurant_id
         AND product_id = stock_row.product_id;
    END LOOP;

    FOR stock_row IN
      SELECT packaging_item_id, SUM(quantity_delta) AS quantity_delta
        FROM public.packaging_movements
       WHERE restaurant_id = p_restaurant_id
         AND reference_type = 'staff_consumption'
       GROUP BY packaging_item_id
    LOOP
      UPDATE public.packaging_stock
         SET quantity_on_hand = GREATEST(
               quantity_on_hand - stock_row.quantity_delta,
               0
             ),
             updated_at = now()
       WHERE restaurant_id = p_restaurant_id
         AND packaging_item_id = stock_row.packaging_item_id;
    END LOOP;

    DELETE FROM public.inventory_movements
     WHERE restaurant_id = p_restaurant_id
       AND reference_type = 'staff_consumption';
    GET DIAGNOSTICS deleted_inventory_movements = ROW_COUNT;

    DELETE FROM public.packaging_movements
     WHERE restaurant_id = p_restaurant_id
       AND reference_type = 'staff_consumption';
    GET DIAGNOSTICS deleted_packaging_movements = ROW_COUNT;

    DELETE FROM public.sale_items item
    USING public.sales sale
     WHERE item.sale_id = sale.id
       AND sale.restaurant_id = p_restaurant_id
       AND sale.sale_kind = 'staff_consumption';
    GET DIAGNOSTICS deleted_sale_items = ROW_COUNT;

    DELETE FROM public.sales
     WHERE restaurant_id = p_restaurant_id
       AND sale_kind = 'staff_consumption';
    GET DIAGNOSTICS deleted_sales = ROW_COUNT;

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
  END IF;

  IF normalized_scope IN ('salary_advances', 'staff_operations') THEN
    DELETE FROM public.operating_expenses
     WHERE restaurant_id = p_restaurant_id
       AND expense_kind = 'salary_advance';
    GET DIAGNOSTICS deleted_expenses = ROW_COUNT;

    DELETE FROM public.employee_salary_advances
     WHERE restaurant_id = p_restaurant_id;
    GET DIAGNOSTICS deleted_salary_advances = ROW_COUNT;
  END IF;

  IF normalized_scope = 'expenses' THEN
    DELETE FROM public.operating_expenses
     WHERE restaurant_id = p_restaurant_id
       AND expense_kind = 'operational';
    GET DIAGNOSTICS deleted_expenses = ROW_COUNT;
  END IF;

  IF normalized_scope = 'sales' THEN
    DELETE FROM public.sale_voids void
    USING public.sales sale
     WHERE void.sale_id = sale.id
       AND sale.restaurant_id = p_restaurant_id
       AND sale.sale_kind = 'sale';
    GET DIAGNOSTICS deleted_sale_voids = ROW_COUNT;

    FOR stock_row IN
      SELECT product_id, SUM(quantity_delta) AS quantity_delta
        FROM public.inventory_movements
       WHERE restaurant_id = p_restaurant_id
         AND reference_type IN ('sale', 'sale_void')
       GROUP BY product_id
    LOOP
      UPDATE public.inventory_stock
         SET quantity_on_hand = GREATEST(
               quantity_on_hand - stock_row.quantity_delta,
               0
             ),
             updated_at = now()
       WHERE restaurant_id = p_restaurant_id
         AND product_id = stock_row.product_id;
    END LOOP;

    FOR stock_row IN
      SELECT packaging_item_id, SUM(quantity_delta) AS quantity_delta
        FROM public.packaging_movements
       WHERE restaurant_id = p_restaurant_id
         AND reference_type IN ('sale', 'sale_void')
       GROUP BY packaging_item_id
    LOOP
      UPDATE public.packaging_stock
         SET quantity_on_hand = GREATEST(
               quantity_on_hand - stock_row.quantity_delta,
               0
             ),
             updated_at = now()
       WHERE restaurant_id = p_restaurant_id
         AND packaging_item_id = stock_row.packaging_item_id;
    END LOOP;

    DELETE FROM public.inventory_movements
     WHERE restaurant_id = p_restaurant_id
       AND reference_type IN ('sale', 'sale_void');
    GET DIAGNOSTICS deleted_inventory_movements = ROW_COUNT;

    DELETE FROM public.packaging_movements
     WHERE restaurant_id = p_restaurant_id
       AND reference_type IN ('sale', 'sale_void');
    GET DIAGNOSTICS deleted_packaging_movements = ROW_COUNT;

    DELETE FROM public.sale_items item
    USING public.sales sale
     WHERE item.sale_id = sale.id
       AND sale.restaurant_id = p_restaurant_id
       AND sale.sale_kind = 'sale';
    GET DIAGNOSTICS deleted_sale_items = ROW_COUNT;

    DELETE FROM public.sales
     WHERE restaurant_id = p_restaurant_id
       AND sale_kind = 'sale';
    GET DIAGNOSTICS deleted_sales = ROW_COUNT;

    DELETE FROM public.table_accounts
     WHERE restaurant_id = p_restaurant_id;
    GET DIAGNOSTICS deleted_table_accounts = ROW_COUNT;

    DELETE FROM public.cash_register_sessions cash
     WHERE cash.restaurant_id = p_restaurant_id
       AND NOT EXISTS (
         SELECT 1 FROM public.operating_expenses expense
          WHERE expense.cash_register_session_id = cash.id
       )
       AND NOT EXISTS (
         SELECT 1 FROM public.employee_salary_advances advance
          WHERE advance.cash_register_session_id = cash.id
       );
    GET DIAGNOSTICS deleted_cash_sessions = ROW_COUNT;

    UPDATE public.invoice_number_settings
       SET next_number = initial_number,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id;
    GET DIAGNOSTICS reset_invoice_settings = ROW_COUNT;
  END IF;

  DELETE FROM public.sync_logs
   WHERE restaurant_id = p_restaurant_id
     AND (
       normalized_scope = 'staff_operations'
       OR entity_name IN (
         CASE normalized_scope
           WHEN 'sales' THEN 'sales'
           WHEN 'expenses' THEN 'operating_expenses'
           WHEN 'salary_advances' THEN 'salary_advances'
           WHEN 'staff_consumptions' THEN 'staff_consumptions'
           WHEN 'payroll' THEN 'payroll'
           ELSE normalized_scope
         END
       )
     );
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
    reset_invoice_settings +
    reset_staff_consumption_settings;

  details := jsonb_build_object(
    'scope', normalized_scope,
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
    'reset_invoice_settings', reset_invoice_settings,
    'reset_staff_consumption_settings', reset_staff_consumption_settings,
    'total_rows', total_rows
  );

  INSERT INTO public.pilot_cleanup_markers (
    restaurant_id,
    scope,
    cleaned_at,
    actor_user_id,
    details
  )
  VALUES (
    p_restaurant_id,
    normalized_scope,
    now(),
    actor_id,
    details
  )
  ON CONFLICT (restaurant_id, scope) DO UPDATE
     SET cleaned_at = excluded.cleaned_at,
         actor_user_id = excluded.actor_user_id,
         details = excluded.details;

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
    'system.pilot_cleanup.' || normalized_scope,
    'restaurants',
    p_restaurant_id,
    details
  );

  RETURN details;
END;
$$;

COMMENT ON FUNCTION public.reset_pilot_operation_scope(uuid, text, text) IS
  'Deletes one pilot/preproduction operational scope while preserving catalogs.';

REVOKE ALL ON FUNCTION public.reset_pilot_operation_scope(uuid, text, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reset_pilot_operation_scope(uuid, text, text)
  TO authenticated;
