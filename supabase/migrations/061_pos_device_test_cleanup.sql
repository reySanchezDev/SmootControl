CREATE OR REPLACE FUNCTION public.app_list_pos_devices_for_cleanup(
  p_restaurant_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'sistema.reiniciar_operacion'
  );

  RETURN COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', device.id,
          'name', COALESCE(device.name, 'POS sin nombre'),
          'is_active', device.is_active,
          'last_seen_at', device.last_seen_at,
          'sales_count', COALESCE(sale_counts.sales_count, 0),
          'staff_consumptions_count',
            COALESCE(sale_counts.staff_consumptions_count, 0),
          'expenses_count', COALESCE(expense_counts.expenses_count, 0),
          'salary_advances_count',
            COALESCE(advance_counts.salary_advances_count, 0),
          'cash_sessions_count', COALESCE(cash_counts.cash_sessions_count, 0),
          'inventory_movements_count',
            COALESCE(inventory_counts.inventory_movements_count, 0),
          'packaging_movements_count',
            COALESCE(packaging_counts.packaging_movements_count, 0),
          'last_activity_at',
            GREATEST(
              COALESCE(sale_counts.last_activity_at, '-infinity'::timestamptz),
              COALESCE(expense_counts.last_activity_at, '-infinity'::timestamptz),
              COALESCE(advance_counts.last_activity_at, '-infinity'::timestamptz),
              COALESCE(cash_counts.last_activity_at, '-infinity'::timestamptz)
            )
        )
        ORDER BY
          GREATEST(
            COALESCE(sale_counts.last_activity_at, '-infinity'::timestamptz),
            COALESCE(expense_counts.last_activity_at, '-infinity'::timestamptz),
            COALESCE(advance_counts.last_activity_at, '-infinity'::timestamptz),
            COALESCE(cash_counts.last_activity_at, '-infinity'::timestamptz),
            COALESCE(device.last_seen_at, '-infinity'::timestamptz)
          ) DESC,
          device.created_at DESC
      )
      FROM public.pos_devices device
      LEFT JOIN LATERAL (
        SELECT
          COUNT(*) FILTER (WHERE sale.sale_kind = 'sale') AS sales_count,
          COUNT(*) FILTER (
            WHERE sale.sale_kind = 'staff_consumption'
          ) AS staff_consumptions_count,
          MAX(sale.sold_at) AS last_activity_at
        FROM public.sales sale
        WHERE sale.restaurant_id = p_restaurant_id
          AND sale.pos_device_id = device.id
      ) sale_counts ON true
      LEFT JOIN LATERAL (
        SELECT COUNT(*) AS expenses_count, MAX(expense.spent_at) AS last_activity_at
        FROM public.operating_expenses expense
        WHERE expense.restaurant_id = p_restaurant_id
          AND expense.pos_device_id = device.id
      ) expense_counts ON true
      LEFT JOIN LATERAL (
        SELECT COUNT(*) AS salary_advances_count,
               MAX(advance.delivered_at) AS last_activity_at
        FROM public.employee_salary_advances advance
        WHERE advance.restaurant_id = p_restaurant_id
          AND advance.pos_device_id = device.id
      ) advance_counts ON true
      LEFT JOIN LATERAL (
        SELECT COUNT(*) AS cash_sessions_count,
               MAX(COALESCE(cash.closed_at, cash.opened_at)) AS last_activity_at
        FROM public.cash_register_sessions cash
        WHERE cash.restaurant_id = p_restaurant_id
          AND cash.pos_device_id = device.id
      ) cash_counts ON true
      LEFT JOIN LATERAL (
        SELECT COUNT(*) AS inventory_movements_count
        FROM public.inventory_movements movement
        WHERE movement.restaurant_id = p_restaurant_id
          AND movement.pos_device_id = device.id
      ) inventory_counts ON true
      LEFT JOIN LATERAL (
        SELECT COUNT(*) AS packaging_movements_count
        FROM public.packaging_movements movement
        WHERE movement.restaurant_id = p_restaurant_id
          AND movement.pos_device_id = device.id
      ) packaging_counts ON true
      WHERE device.restaurant_id = p_restaurant_id
    ),
    '[]'::jsonb
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_cleanup_pos_device_test_data(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_confirmation text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_sale_voids integer := 0;
  deleted_sale_items integer := 0;
  deleted_sales integer := 0;
  deleted_expenses integer := 0;
  deleted_salary_advances integer := 0;
  deleted_cash_sessions integer := 0;
  deleted_inventory_movements integer := 0;
  deleted_packaging_movements integer := 0;
  deleted_sync_logs integer := 0;
  total_rows integer := 0;
  details jsonb;
  stock_row record;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'sistema.reiniciar_operacion'
  );

  IF p_confirmation <> 'BORRAR DISPOSITIVO' THEN
    RAISE EXCEPTION 'Confirmacion invalida para limpieza por dispositivo'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.pos_devices
    WHERE id = p_device_id
      AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Dispositivo POS no encontrado'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.sales
    WHERE restaurant_id = p_restaurant_id
      AND pos_device_id = p_device_id
      AND sale_kind = 'staff_consumption'
      AND payroll_run_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION
      'Primero debes revertir la planilla aplicada a consumos de este dispositivo'
      USING ERRCODE = '23503';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.employee_salary_advances
    WHERE restaurant_id = p_restaurant_id
      AND pos_device_id = p_device_id
      AND status IN ('partially_paid', 'paid')
  ) THEN
    RAISE EXCEPTION
      'Primero debes revertir pagos de planilla ligados a adelantos de este dispositivo'
      USING ERRCODE = '23503';
  END IF;

  DELETE FROM public.sale_voids void
  USING public.sales sale
  WHERE void.sale_id = sale.id
    AND sale.restaurant_id = p_restaurant_id
    AND sale.pos_device_id = p_device_id;
  GET DIAGNOSTICS deleted_sale_voids = ROW_COUNT;

  FOR stock_row IN
    SELECT product_id, SUM(quantity_delta) AS quantity_delta
    FROM public.inventory_movements
    WHERE restaurant_id = p_restaurant_id
      AND pos_device_id = p_device_id
    GROUP BY product_id
  LOOP
    UPDATE public.inventory_stock
    SET quantity_on_hand = quantity_on_hand - stock_row.quantity_delta,
        updated_at = now()
    WHERE restaurant_id = p_restaurant_id
      AND product_id = stock_row.product_id;
  END LOOP;

  FOR stock_row IN
    SELECT packaging_item_id, SUM(quantity_delta) AS quantity_delta
    FROM public.packaging_movements
    WHERE restaurant_id = p_restaurant_id
      AND pos_device_id = p_device_id
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
    AND pos_device_id = p_device_id;
  GET DIAGNOSTICS deleted_inventory_movements = ROW_COUNT;

  DELETE FROM public.packaging_movements
  WHERE restaurant_id = p_restaurant_id
    AND pos_device_id = p_device_id;
  GET DIAGNOSTICS deleted_packaging_movements = ROW_COUNT;

  DELETE FROM public.sale_items item
  USING public.sales sale
  WHERE item.sale_id = sale.id
    AND sale.restaurant_id = p_restaurant_id
    AND sale.pos_device_id = p_device_id;
  GET DIAGNOSTICS deleted_sale_items = ROW_COUNT;

  DELETE FROM public.sales
  WHERE restaurant_id = p_restaurant_id
    AND pos_device_id = p_device_id;
  GET DIAGNOSTICS deleted_sales = ROW_COUNT;

  DELETE FROM public.operating_expenses
  WHERE restaurant_id = p_restaurant_id
    AND pos_device_id = p_device_id;
  GET DIAGNOSTICS deleted_expenses = ROW_COUNT;

  DELETE FROM public.employee_salary_advances
  WHERE restaurant_id = p_restaurant_id
    AND pos_device_id = p_device_id;
  GET DIAGNOSTICS deleted_salary_advances = ROW_COUNT;

  DELETE FROM public.cash_register_sessions cash
  WHERE cash.restaurant_id = p_restaurant_id
    AND cash.pos_device_id = p_device_id
    AND NOT EXISTS (
      SELECT 1 FROM public.sales sale
      WHERE sale.cash_register_session_id = cash.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.operating_expenses expense
      WHERE expense.cash_register_session_id = cash.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.employee_salary_advances advance
      WHERE advance.cash_register_session_id = cash.id
    );
  GET DIAGNOSTICS deleted_cash_sessions = ROW_COUNT;

  DELETE FROM public.sync_logs
  WHERE restaurant_id = p_restaurant_id
    AND details ->> 'pos_device_id' = p_device_id::text;
  GET DIAGNOSTICS deleted_sync_logs = ROW_COUNT;

  total_rows := deleted_sale_voids + deleted_sale_items + deleted_sales +
    deleted_expenses + deleted_salary_advances + deleted_cash_sessions +
    deleted_inventory_movements + deleted_packaging_movements +
    deleted_sync_logs;

  details := jsonb_build_object(
    'device_id', p_device_id,
    'deleted_sale_voids', deleted_sale_voids,
    'deleted_sale_items', deleted_sale_items,
    'deleted_sales', deleted_sales,
    'deleted_expenses', deleted_expenses,
    'deleted_salary_advances', deleted_salary_advances,
    'deleted_cash_sessions', deleted_cash_sessions,
    'deleted_inventory_movements', deleted_inventory_movements,
    'deleted_packaging_movements', deleted_packaging_movements,
    'deleted_sync_logs', deleted_sync_logs,
    'total_rows', total_rows
  );

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
    auth.uid(),
    'system.cleanup_pos_device',
    'pos_devices',
    p_device_id,
    details
  );

  RETURN details;
END;
$$;

REVOKE ALL ON FUNCTION public.app_list_pos_devices_for_cleanup(uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_cleanup_pos_device_test_data(uuid, uuid, text)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_list_pos_devices_for_cleanup(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_cleanup_pos_device_test_data(uuid, uuid, text)
  TO authenticated;
