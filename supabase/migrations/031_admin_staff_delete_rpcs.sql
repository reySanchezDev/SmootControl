CREATE OR REPLACE FUNCTION public.app_delete_staff_consumption(
  p_restaurant_id uuid,
  p_sale_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  inventory_row record;
  packaging_row record;
  deleted_items integer := 0;
  deleted_inventory integer := 0;
  deleted_packaging integer := 0;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'personal.consumos.registrar'
  );

  IF NOT EXISTS (
    SELECT 1
      FROM public.sales
     WHERE id = p_sale_id
       AND restaurant_id = p_restaurant_id
       AND sale_kind = 'staff_consumption'
  ) THEN
    RAISE EXCEPTION 'Consumo de personal no encontrado';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.sales
     WHERE id = p_sale_id
       AND restaurant_id = p_restaurant_id
       AND sale_kind = 'staff_consumption'
       AND payroll_run_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'No se puede eliminar un consumo ya aplicado a planilla';
  END IF;

  FOR inventory_row IN
    SELECT product_id, quantity_delta
      FROM public.inventory_movements
     WHERE restaurant_id = p_restaurant_id
       AND reference_type = 'staff_consumption'
       AND reference_id = p_sale_id::text
  LOOP
    UPDATE public.inventory_stock
       SET quantity_on_hand = quantity_on_hand - inventory_row.quantity_delta,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id
       AND product_id = inventory_row.product_id;
  END LOOP;

  FOR packaging_row IN
    SELECT packaging_item_id, quantity_delta
      FROM public.packaging_movements
     WHERE restaurant_id = p_restaurant_id
       AND reference_type = 'staff_consumption'
       AND reference_id = p_sale_id::text
  LOOP
    UPDATE public.packaging_stock
       SET quantity_on_hand = quantity_on_hand - packaging_row.quantity_delta,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id
       AND packaging_item_id = packaging_row.packaging_item_id;
  END LOOP;

  DELETE FROM public.inventory_movements
   WHERE restaurant_id = p_restaurant_id
     AND reference_type = 'staff_consumption'
     AND reference_id = p_sale_id::text;
  GET DIAGNOSTICS deleted_inventory = ROW_COUNT;

  DELETE FROM public.packaging_movements
   WHERE restaurant_id = p_restaurant_id
     AND reference_type = 'staff_consumption'
     AND reference_id = p_sale_id::text;
  GET DIAGNOSTICS deleted_packaging = ROW_COUNT;

  DELETE FROM public.sale_items
   WHERE sale_id = p_sale_id;
  GET DIAGNOSTICS deleted_items = ROW_COUNT;

  DELETE FROM public.sales
   WHERE id = p_sale_id
     AND restaurant_id = p_restaurant_id
     AND sale_kind = 'staff_consumption';

  RETURN jsonb_build_object(
    'deleted_sale_id', p_sale_id,
    'deleted_items', deleted_items,
    'deleted_inventory_movements', deleted_inventory,
    'deleted_packaging_movements', deleted_packaging
  );
END;
$$;

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

  UPDATE public.payroll_run_lines
     SET details = details - 'salary_advance_id' - 'advance_id',
         created_at = created_at
   WHERE details ->> 'salary_advance_id' = p_advance_id::text
      OR details ->> 'advance_id' = p_advance_id::text;

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

REVOKE ALL ON FUNCTION public.app_delete_staff_consumption(uuid, uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_delete_salary_advance(uuid, uuid)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_delete_staff_consumption(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_delete_salary_advance(uuid, uuid)
  TO authenticated;
