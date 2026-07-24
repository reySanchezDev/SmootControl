CREATE OR REPLACE FUNCTION public.app_save_raw_material_staff_consumption(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  consumption_id_value uuid := COALESCE(
    NULLIF(p_payload ->> 'id', '')::uuid,
    gen_random_uuid()
  );
  employee_id_value uuid := (p_payload ->> 'employee_id')::uuid;
  consumed_at_value timestamptz := COALESCE(
    NULLIF(p_payload ->> 'consumed_at', '')::timestamptz,
    now()
  );
  note_value text := NULLIF(p_payload ->> 'note', '');
  line_payload jsonb;
  line_id uuid;
  product_row record;
  unit_row record;
  quantity_value numeric;
  inventory_quantity_value numeric;
  price_value numeric;
  subtotal_value numeric;
  total_value numeric := 0;
  old_movement record;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'personal.consumos_materia.registrar'
  );

  IF NOT EXISTS (
    SELECT 1 FROM public.employees
     WHERE id = employee_id_value
       AND restaurant_id = p_restaurant_id
       AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Empleado invalido';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.employee_raw_material_consumptions
     WHERE id = consumption_id_value
       AND restaurant_id = p_restaurant_id
       AND payroll_run_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'No se puede editar un consumo aplicado a planilla';
  END IF;

  FOR old_movement IN
    SELECT product_id, quantity_delta
      FROM public.inventory_movements
     WHERE restaurant_id = p_restaurant_id
       AND reference_type = 'staff_raw_material_consumption'
       AND reference_id = consumption_id_value::text
  LOOP
    UPDATE public.inventory_stock
       SET quantity_on_hand = quantity_on_hand - old_movement.quantity_delta,
           updated_at = now()
     WHERE restaurant_id = p_restaurant_id
       AND product_id = old_movement.product_id;
  END LOOP;

  DELETE FROM public.inventory_movements
   WHERE restaurant_id = p_restaurant_id
     AND reference_type = 'staff_raw_material_consumption'
     AND reference_id = consumption_id_value::text;

  DELETE FROM public.employee_raw_material_consumption_lines
   WHERE consumption_id = consumption_id_value;

  INSERT INTO public.employee_raw_material_consumptions (
    id, restaurant_id, employee_id, consumed_at, note, total_amount,
    created_by_user_id, created_at, updated_at
  )
  VALUES (
    consumption_id_value, p_restaurant_id, employee_id_value, consumed_at_value,
    note_value, 0, auth.uid(), now(), now()
  )
  ON CONFLICT (id) DO UPDATE
     SET employee_id = EXCLUDED.employee_id,
         consumed_at = EXCLUDED.consumed_at,
         note = EXCLUDED.note,
         updated_at = now();

  FOR line_payload IN
    SELECT * FROM jsonb_array_elements(COALESCE(p_payload -> 'lines', '[]'))
  LOOP
    line_id := COALESCE(
      NULLIF(line_payload ->> 'id', '')::uuid,
      gen_random_uuid()
    );
    quantity_value := (line_payload ->> 'quantity')::numeric;
    price_value := (line_payload ->> 'unit_price')::numeric;

    IF quantity_value <= 0 OR price_value < 0 THEN
      RAISE EXCEPTION 'Linea de consumo invalida';
    END IF;

    SELECT *
      INTO product_row
      FROM public.products product
     WHERE product.id = (line_payload ->> 'product_id')::uuid
       AND product.restaurant_id = p_restaurant_id
       AND product.is_active = true
       AND COALESCE(product.is_raw_material, false) = true;

    IF product_row.id IS NULL THEN
      RAISE EXCEPTION 'Materia prima invalida';
    END IF;

    SELECT * INTO unit_row
      FROM public.measurement_units
     WHERE id = NULLIF(line_payload ->> 'unit_id', '')::uuid;

    inventory_quantity_value := public.app_raw_material_stock_quantity(
      p_restaurant_id,
      product_row.id,
      unit_row.id,
      quantity_value
    );
    subtotal_value := quantity_value * price_value;
    total_value := total_value + subtotal_value;

    INSERT INTO public.employee_raw_material_consumption_lines (
      id, consumption_id, product_id, product_name, quantity,
      inventory_quantity, unit_id, unit_name, unit_code, unit_price, subtotal
    )
    VALUES (
      line_id, consumption_id_value, product_row.id, product_row.name,
      quantity_value, inventory_quantity_value, unit_row.id,
      unit_row.name, unit_row.code, price_value, subtotal_value
    );

    PERFORM public.apply_inventory_movement(
      'staff-raw-' || line_id::text,
      p_restaurant_id,
      product_row.id,
      'staff_raw_material_consumption',
      -inventory_quantity_value,
      'staff_raw_material_consumption',
      consumption_id_value::text,
      auth.uid()::text,
      'Consumo de materia prima de personal',
      consumed_at_value,
      0
    );
  END LOOP;

  IF total_value <= 0 THEN
    RAISE EXCEPTION 'Agrega al menos una materia prima';
  END IF;

  UPDATE public.employee_raw_material_consumptions
     SET total_amount = total_value,
         updated_at = now()
   WHERE id = consumption_id_value;

  RETURN jsonb_build_object(
    'id',
    consumption_id_value,
    'total_amount',
    total_value
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_save_raw_material_staff_consumption(
  uuid, jsonb
) TO authenticated;
