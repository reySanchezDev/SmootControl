CREATE OR REPLACE FUNCTION public.app_get_raw_material_staff_consumptions(
  p_restaurant_id uuid,
  p_from date,
  p_to date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'personal.consumos_materia.ver'
  );

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', consumption.id,
        'employee_id', consumption.employee_id,
        'employee_name', employee.full_name,
        'consumed_at', consumption.consumed_at,
        'note', consumption.note,
        'total_amount', consumption.total_amount,
        'payroll_run_id', consumption.payroll_run_id,
        'lines', COALESCE(lines.rows, '[]'::jsonb)
      )
      ORDER BY consumption.consumed_at DESC, consumption.created_at DESC
    )
      FROM public.employee_raw_material_consumptions consumption
      JOIN public.employees employee ON employee.id = consumption.employee_id
      LEFT JOIN LATERAL (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', line.id,
            'product_id', line.product_id,
            'product_name', line.product_name,
            'quantity', line.quantity,
            'inventory_quantity', line.inventory_quantity,
            'unit_id', line.unit_id,
            'unit_name', line.unit_name,
            'unit_code', line.unit_code,
            'unit_price', line.unit_price,
            'subtotal', line.subtotal
          )
          ORDER BY line.created_at, line.id
        ) AS rows
          FROM public.employee_raw_material_consumption_lines line
         WHERE line.consumption_id = consumption.id
      ) lines ON true
     WHERE consumption.restaurant_id = p_restaurant_id
       AND consumption.consumed_at::date BETWEEN p_from AND p_to
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_delete_raw_material_staff_consumption(
  p_restaurant_id uuid,
  p_consumption_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  stock_row record;
  deleted_lines integer := 0;
  deleted_movements integer := 0;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'personal.consumos_materia.registrar'
  );

  IF NOT EXISTS (
    SELECT 1
      FROM public.employee_raw_material_consumptions
     WHERE id = p_consumption_id
       AND restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Consumo de materia prima no encontrado';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.employee_raw_material_consumptions
     WHERE id = p_consumption_id
       AND restaurant_id = p_restaurant_id
       AND payroll_run_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'No se puede eliminar un consumo aplicado a planilla';
  END IF;

  FOR stock_row IN
    SELECT product_id, quantity_delta
      FROM public.inventory_movements
     WHERE restaurant_id = p_restaurant_id
       AND reference_type = 'staff_raw_material_consumption'
       AND reference_id = p_consumption_id::text
  LOOP
    UPDATE public.inventory_stock
       SET quantity_on_hand = quantity_on_hand - stock_row.quantity_delta,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id
       AND product_id = stock_row.product_id;
  END LOOP;

  DELETE FROM public.inventory_movements
   WHERE restaurant_id = p_restaurant_id
     AND reference_type = 'staff_raw_material_consumption'
     AND reference_id = p_consumption_id::text;
  GET DIAGNOSTICS deleted_movements = ROW_COUNT;

  DELETE FROM public.employee_raw_material_consumption_lines
   WHERE consumption_id = p_consumption_id;
  GET DIAGNOSTICS deleted_lines = ROW_COUNT;

  DELETE FROM public.employee_raw_material_consumptions
   WHERE id = p_consumption_id
     AND restaurant_id = p_restaurant_id;

  RETURN jsonb_build_object(
    'deleted_consumption_id', p_consumption_id,
    'deleted_lines', deleted_lines,
    'deleted_inventory_movements', deleted_movements
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_get_raw_material_staff_consumptions(
  uuid, date, date
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.app_delete_raw_material_staff_consumption(
  uuid, uuid
) TO authenticated;
