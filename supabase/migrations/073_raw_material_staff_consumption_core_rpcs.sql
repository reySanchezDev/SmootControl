ALTER TABLE public.inventory_movements
  DROP CONSTRAINT IF EXISTS inventory_movements_movement_type_check;

ALTER TABLE public.inventory_movements
  ADD CONSTRAINT inventory_movements_movement_type_check
  CHECK (
    movement_type IN (
      'purchase',
      'sale',
      'sale_void',
      'adjustment',
      'recipe_consumption',
      'staff_raw_material_consumption'
    )
  );

CREATE OR REPLACE FUNCTION public.app_raw_material_stock_quantity(
  p_restaurant_id uuid,
  p_product_id uuid,
  p_unit_id uuid,
  p_quantity numeric
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  product_row record;
  line_unit record;
  inventory_unit record;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Cantidad invalida';
  END IF;

  SELECT *
    INTO product_row
    FROM public.products product
   WHERE product.id = p_product_id
     AND product.restaurant_id = p_restaurant_id
     AND product.is_active = true
     AND COALESCE(product.is_raw_material, false) = true;

  IF product_row.id IS NULL THEN
    RAISE EXCEPTION 'Materia prima invalida';
  END IF;

  IF p_unit_id IS NULL THEN
    RETURN p_quantity;
  END IF;

  IF p_unit_id = product_row.inventory_unit_id THEN
    RETURN p_quantity;
  END IF;

  IF p_unit_id = product_row.purchase_unit_id THEN
    IF product_row.purchase_to_inventory_factor IS NULL
       OR product_row.purchase_to_inventory_factor <= 0 THEN
      RAISE EXCEPTION 'Producto sin conversion de compra a inventario';
    END IF;
    RETURN p_quantity * product_row.purchase_to_inventory_factor;
  END IF;

  SELECT * INTO line_unit
    FROM public.measurement_units
   WHERE id = p_unit_id
     AND is_active = true
     AND (restaurant_id IS NULL OR restaurant_id = p_restaurant_id);

  SELECT * INTO inventory_unit
    FROM public.measurement_units
   WHERE id = product_row.inventory_unit_id
     AND is_active = true
     AND (restaurant_id IS NULL OR restaurant_id = p_restaurant_id);

  IF line_unit.id IS NULL OR inventory_unit.id IS NULL
     OR line_unit.unit_group <> inventory_unit.unit_group THEN
    RAISE EXCEPTION 'Unidad incompatible con la materia prima';
  END IF;

  RETURN p_quantity * line_unit.base_factor / inventory_unit.base_factor;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_get_raw_material_product_options(
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
    'personal.consumos_materia.ver'
  );

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', product.id,
        'name', product.name,
        'cost', product.cost,
        'purchase_unit_id', product.purchase_unit_id,
        'inventory_unit_id', product.inventory_unit_id,
        'recipe_default_unit_id', product.recipe_default_unit_id,
        'inventory_display_unit_id', product.inventory_display_unit_id,
        'purchase_to_inventory_factor', product.purchase_to_inventory_factor
      )
      ORDER BY product.name
    )
      FROM public.products product
     WHERE product.restaurant_id = p_restaurant_id
       AND product.is_active = true
       AND COALESCE(product.is_raw_material, false) = true
  ), '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_raw_material_stock_quantity(
  uuid, uuid, uuid, numeric
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.app_get_raw_material_product_options(uuid)
  TO authenticated;
