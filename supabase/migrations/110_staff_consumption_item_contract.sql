-- Move administrative raw-material consumption to items/item_id.
BEGIN;

ALTER TABLE public.employee_raw_material_consumption_lines
  ADD COLUMN IF NOT EXISTS item_id uuid REFERENCES public.items(id);

UPDATE public.employee_raw_material_consumption_lines line
SET item_id = line.product_id
WHERE line.item_id IS NULL;

ALTER TABLE public.employee_raw_material_consumption_lines
  ALTER COLUMN product_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS employee_raw_material_lines_item_idx
  ON public.employee_raw_material_consumption_lines(consumption_id, item_id);

CREATE OR REPLACE FUNCTION public.app_raw_material_stock_quantity(
  p_restaurant_id uuid, p_product_id uuid, p_unit_id uuid, p_quantity numeric
) RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE item_row record; line_unit record; base_unit record;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Cantidad invalida';
  END IF;
  SELECT * INTO item_row FROM public.items item
  WHERE item.id = p_product_id AND item.restaurant_id = p_restaurant_id
    AND item.is_active AND item.tracks_inventory
    AND item.item_class = 'raw_material';
  IF item_row.id IS NULL THEN RAISE EXCEPTION 'Materia prima invalida'; END IF;
  IF p_unit_id IS NULL OR p_unit_id = item_row.base_unit_id THEN
    RETURN p_quantity;
  END IF;
  IF p_unit_id = item_row.purchase_unit_id THEN
    IF coalesce(item_row.purchase_to_base_factor, 0) <= 0 THEN
      RAISE EXCEPTION 'Materia prima sin conversion de compra';
    END IF;
    RETURN p_quantity * item_row.purchase_to_base_factor;
  END IF;
  SELECT * INTO line_unit FROM public.measurement_units
  WHERE id = p_unit_id AND is_active
    AND (restaurant_id IS NULL OR restaurant_id = p_restaurant_id);
  SELECT * INTO base_unit FROM public.measurement_units
  WHERE id = item_row.base_unit_id AND is_active
    AND (restaurant_id IS NULL OR restaurant_id = p_restaurant_id);
  IF line_unit.id IS NULL OR base_unit.id IS NULL
     OR line_unit.unit_group <> base_unit.unit_group THEN
    RAISE EXCEPTION 'Unidad incompatible con la materia prima';
  END IF;
  RETURN p_quantity * line_unit.base_factor / base_unit.base_factor;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_get_raw_material_product_options(
  p_restaurant_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id, 'personal.consumos_materia.ver'
  );
  RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
    'id', item.id, 'name', item.name, 'cost', item.base_unit_cost,
    'purchase_unit_id', item.purchase_unit_id,
    'inventory_unit_id', item.base_unit_id,
    'recipe_default_unit_id', item.base_unit_id,
    'inventory_display_unit_id', item.base_unit_id,
    'purchase_to_inventory_factor', item.purchase_to_base_factor
  ) ORDER BY item.name) FROM public.items item
  WHERE item.restaurant_id = p_restaurant_id AND item.is_active
    AND item.tracks_inventory AND item.item_class = 'raw_material'), '[]');
END;
$$;

CREATE OR REPLACE FUNCTION public.app_get_raw_material_staff_consumptions(
  p_restaurant_id uuid, p_from date, p_to date
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id, 'personal.consumos_materia.ver'
  );
  RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
    'id', consumption.id, 'employee_id', consumption.employee_id,
    'employee_name', employee.full_name, 'consumed_at', consumption.consumed_at,
    'note', consumption.note, 'total_amount', consumption.total_amount,
    'payroll_run_id', consumption.payroll_run_id,
    'lines', coalesce(lines.rows, '[]')
  ) ORDER BY consumption.consumed_at DESC, consumption.created_at DESC)
  FROM public.employee_raw_material_consumptions consumption
  JOIN public.employees employee ON employee.id = consumption.employee_id
  LEFT JOIN LATERAL (SELECT jsonb_agg(jsonb_build_object(
    'id', line.id, 'item_id', line.item_id, 'product_id', line.item_id,
    'product_name', line.product_name, 'quantity', line.quantity,
    'inventory_quantity', line.inventory_quantity, 'unit_id', line.unit_id,
    'unit_name', line.unit_name, 'unit_code', line.unit_code,
    'unit_price', line.unit_price, 'subtotal', line.subtotal
  ) ORDER BY line.created_at, line.id) rows
  FROM public.employee_raw_material_consumption_lines line
  WHERE line.consumption_id = consumption.id) lines ON true
  WHERE consumption.restaurant_id = p_restaurant_id
    AND consumption.consumed_at::date BETWEEN p_from AND p_to), '[]');
END;
$$;

CREATE OR REPLACE FUNCTION public.app_save_raw_material_staff_consumption(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  consumption_id_value uuid := coalesce(nullif(p_payload ->> 'id', '')::uuid, gen_random_uuid());
  employee_id_value uuid := (p_payload ->> 'employee_id')::uuid;
  consumed_at_value timestamptz := coalesce(nullif(p_payload ->> 'consumed_at', '')::timestamptz, now());
  line_payload jsonb; item_row record; unit_row record; line_id uuid;
  quantity_value numeric; inventory_quantity_value numeric; price_value numeric;
  subtotal_value numeric; total_value numeric := 0; old_movement record;
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'personal.consumos_materia.registrar');
  IF NOT EXISTS (SELECT 1 FROM public.employees WHERE id = employee_id_value
    AND restaurant_id = p_restaurant_id AND is_active) THEN
    RAISE EXCEPTION 'Empleado invalido';
  END IF;
  IF EXISTS (SELECT 1 FROM public.employee_raw_material_consumptions
    WHERE id = consumption_id_value AND restaurant_id = p_restaurant_id
      AND payroll_run_id IS NOT NULL) THEN
    RAISE EXCEPTION 'No se puede editar un consumo aplicado a planilla';
  END IF;
  FOR old_movement IN SELECT item_id, quantity_delta FROM public.inventory_movements
    WHERE restaurant_id = p_restaurant_id
      AND reference_type = 'staff_raw_material_consumption'
      AND reference_id = consumption_id_value::text AND item_id IS NOT NULL
  LOOP
    PERFORM public.apply_inventory_movement_v2(
      'staff-revert:' || consumption_id_value || ':' || old_movement.item_id,
      p_restaurant_id, old_movement.item_id, NULL, 'adjustment',
      -old_movement.quantity_delta, 'staff_raw_material_consumption',
      consumption_id_value::text, auth.uid()::text, 'Reversion de consumo', now(), 0);
  END LOOP;
  DELETE FROM public.inventory_movements WHERE restaurant_id = p_restaurant_id
    AND reference_type = 'staff_raw_material_consumption'
    AND reference_id = consumption_id_value::text;
  DELETE FROM public.employee_raw_material_consumption_lines
    WHERE consumption_id = consumption_id_value;
  INSERT INTO public.employee_raw_material_consumptions(
    id, restaurant_id, employee_id, consumed_at, note, total_amount,
    created_by_user_id, created_at, updated_at)
  VALUES (consumption_id_value, p_restaurant_id, employee_id_value, consumed_at_value,
    nullif(p_payload ->> 'note', ''), 0, auth.uid(), now(), now())
  ON CONFLICT (id) DO UPDATE SET employee_id = excluded.employee_id,
    consumed_at = excluded.consumed_at, note = excluded.note, updated_at = now();
  FOR line_payload IN SELECT value FROM jsonb_array_elements(coalesce(p_payload -> 'lines', '[]')) LOOP
    line_id := coalesce(nullif(line_payload ->> 'id', '')::uuid, gen_random_uuid());
    quantity_value := (line_payload ->> 'quantity')::numeric;
    price_value := (line_payload ->> 'unit_price')::numeric;
    SELECT * INTO item_row FROM public.items item WHERE item.id =
      (line_payload ->> 'item_id')::uuid AND item.restaurant_id = p_restaurant_id
      AND item.is_active AND item.tracks_inventory AND item.item_class = 'raw_material';
    IF item_row.id IS NULL OR quantity_value <= 0 OR price_value < 0 THEN
      RAISE EXCEPTION 'Linea de consumo invalida';
    END IF;
    SELECT * INTO unit_row FROM public.measurement_units
      WHERE id = nullif(line_payload ->> 'unit_id', '')::uuid;
    inventory_quantity_value := public.app_raw_material_stock_quantity(
      p_restaurant_id, item_row.id, unit_row.id, quantity_value);
    subtotal_value := quantity_value * price_value; total_value := total_value + subtotal_value;
    INSERT INTO public.employee_raw_material_consumption_lines(
      id, consumption_id, product_id, item_id, product_name, quantity,
      inventory_quantity, unit_id, unit_name, unit_code, unit_price, subtotal)
    VALUES (line_id, consumption_id_value, NULL, item_row.id, item_row.name,
      quantity_value, inventory_quantity_value, unit_row.id, unit_row.name,
      unit_row.code, price_value, subtotal_value);
    PERFORM public.apply_inventory_movement_v2(
      'staff-raw-' || line_id::text, p_restaurant_id, item_row.id, NULL,
      'staff_raw_material_consumption', -inventory_quantity_value,
      'staff_raw_material_consumption', consumption_id_value::text,
      auth.uid()::text, 'Consumo de materia prima de personal', consumed_at_value, 0);
  END LOOP;
  IF total_value <= 0 THEN RAISE EXCEPTION 'Agrega al menos una materia prima'; END IF;
  UPDATE public.employee_raw_material_consumptions SET total_amount = total_value,
    updated_at = now() WHERE id = consumption_id_value;
  RETURN jsonb_build_object('id', consumption_id_value, 'total_amount', total_value);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_delete_raw_material_staff_consumption(
  p_restaurant_id uuid, p_consumption_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE movement_row record; deleted_lines integer := 0; deleted_movements integer := 0;
BEGIN
  PERFORM public.app_assert_admin_permission(p_restaurant_id, 'personal.consumos_materia.registrar');
  IF NOT EXISTS (SELECT 1 FROM public.employee_raw_material_consumptions
    WHERE id = p_consumption_id AND restaurant_id = p_restaurant_id) THEN
    RAISE EXCEPTION 'Consumo de materia prima no encontrado';
  END IF;
  IF EXISTS (SELECT 1 FROM public.employee_raw_material_consumptions
    WHERE id = p_consumption_id AND restaurant_id = p_restaurant_id
      AND payroll_run_id IS NOT NULL) THEN
    RAISE EXCEPTION 'No se puede eliminar un consumo aplicado a planilla';
  END IF;
  FOR movement_row IN SELECT item_id, quantity_delta FROM public.inventory_movements
    WHERE restaurant_id = p_restaurant_id
      AND reference_type = 'staff_raw_material_consumption'
      AND reference_id = p_consumption_id::text AND item_id IS NOT NULL
  LOOP
    PERFORM public.apply_inventory_movement_v2(
      'staff-delete:' || p_consumption_id || ':' || movement_row.item_id,
      p_restaurant_id, movement_row.item_id, NULL, 'adjustment',
      -movement_row.quantity_delta, 'staff_raw_material_consumption',
      p_consumption_id::text, auth.uid()::text, 'Eliminacion de consumo', now(), 0);
  END LOOP;
  DELETE FROM public.inventory_movements WHERE restaurant_id = p_restaurant_id
    AND reference_type = 'staff_raw_material_consumption'
    AND reference_id = p_consumption_id::text;
  GET DIAGNOSTICS deleted_movements = ROW_COUNT;
  DELETE FROM public.employee_raw_material_consumption_lines
    WHERE consumption_id = p_consumption_id;
  GET DIAGNOSTICS deleted_lines = ROW_COUNT;
  DELETE FROM public.employee_raw_material_consumptions
    WHERE id = p_consumption_id AND restaurant_id = p_restaurant_id;
  RETURN jsonb_build_object('deleted_consumption_id', p_consumption_id,
    'deleted_lines', deleted_lines, 'deleted_inventory_movements', deleted_movements);
END;
$$;

REVOKE ALL ON FUNCTION public.app_raw_material_stock_quantity(uuid,uuid,uuid,numeric) FROM PUBLIC;
COMMIT;
