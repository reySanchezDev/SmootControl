-- Raw material product cost is captured in the purchase unit.
-- Inventory and recipes still work in the product base unit, deriving the base
-- cost from purchase cost / purchase_to_inventory_factor when needed.

DROP FUNCTION IF EXISTS public.apply_inventory_movement(
  text,
  uuid,
  uuid,
  text,
  integer,
  text,
  text,
  text,
  text,
  timestamptz,
  numeric
);

CREATE OR REPLACE FUNCTION public.apply_inventory_movement(
  p_id text,
  p_restaurant_id uuid,
  p_product_id uuid,
  p_movement_type text,
  p_quantity_delta numeric,
  p_reference_type text DEFAULT NULL,
  p_reference_id text DEFAULT NULL,
  p_user_id text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_created_at timestamptz DEFAULT NULL,
  p_unit_cost numeric DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_quantity numeric(18, 6);
  next_quantity numeric(18, 6);
BEGIN
  IF NOT public.is_same_restaurant(p_restaurant_id) THEN
    RAISE EXCEPTION 'No autorizado para inventario del restaurante %',
      p_restaurant_id
      USING ERRCODE = '42501';
  END IF;

  IF p_id IS NULL OR btrim(p_id) = '' THEN
    RAISE EXCEPTION 'Movimiento de inventario sin id'
      USING ERRCODE = '23502';
  END IF;

  IF p_movement_type NOT IN (
    'purchase',
    'sale',
    'sale_void',
    'adjustment',
    'recipe_consumption'
  ) THEN
    RAISE EXCEPTION 'Tipo de movimiento de inventario invalido: %',
      p_movement_type
      USING ERRCODE = '23514';
  END IF;

  IF p_quantity_delta IS NULL OR p_quantity_delta = 0 THEN
    RAISE EXCEPTION 'Cantidad de inventario invalida'
      USING ERRCODE = '23514';
  END IF;

  IF COALESCE(p_unit_cost, 0) < 0 THEN
    RAISE EXCEPTION 'Costo unitario de inventario invalido'
      USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM public.products product
     WHERE product.id = p_product_id
       AND product.restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'Producto no pertenece al restaurante'
      USING ERRCODE = '23503';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.inventory_movements
    WHERE id = p_id
  ) THEN
    RETURN;
  END IF;

  INSERT INTO public.inventory_stock (
    restaurant_id, product_id, quantity_on_hand, created_at, updated_at
  )
  VALUES (p_restaurant_id, p_product_id, 0, now(), now())
  ON CONFLICT (restaurant_id, product_id) DO NOTHING;

  SELECT quantity_on_hand INTO current_quantity
  FROM public.inventory_stock
  WHERE restaurant_id = p_restaurant_id
    AND product_id = p_product_id
  FOR UPDATE;

  next_quantity := current_quantity + p_quantity_delta;

  INSERT INTO public.inventory_movements (
    id, restaurant_id, product_id, movement_type, quantity_delta,
    reference_type, reference_id, user_id, notes, created_at, unit_cost
  )
  VALUES (
    p_id, p_restaurant_id, p_product_id, p_movement_type, p_quantity_delta,
    p_reference_type, p_reference_id, p_user_id, p_notes,
    COALESCE(p_created_at, now()), COALESCE(p_unit_cost, 0)
  );

  UPDATE public.inventory_stock
     SET quantity_on_hand = next_quantity,
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
     AND product_id = p_product_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_register_inventory_purchase_batch(
  p_restaurant_id uuid,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item_payload jsonb;
  item_count integer := 0;
  product_id uuid;
  quantity numeric;
  target_quantity numeric;
  purchase_unit_cost numeric;
  base_unit_cost numeric;
  movement_id text;
  purchase_unit_id uuid;
  product_row public.products%ROWTYPE;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'inventario.gestionar'
  );

  IF jsonb_typeof(COALESCE(p_items, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'Lista de productos invalida'
      USING ERRCODE = '22023';
  END IF;

  FOR item_payload IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    product_id := (item_payload ->> 'product_id')::uuid;
    quantity := (item_payload ->> 'quantity')::numeric;
    purchase_unit_cost := (item_payload ->> 'unit_cost')::numeric;
    purchase_unit_id := NULLIF(item_payload ->> 'purchase_unit_id', '')::uuid;

    IF quantity IS NULL OR quantity <= 0 THEN
      RAISE EXCEPTION 'Cantidad de producto invalida'
        USING ERRCODE = '23514';
    END IF;

    IF purchase_unit_cost IS NULL OR purchase_unit_cost < 0 THEN
      RAISE EXCEPTION 'Costo unitario de producto invalido'
        USING ERRCODE = '23514';
    END IF;

    SELECT *
      INTO product_row
      FROM public.products product
     WHERE product.id = product_id
       AND product.restaurant_id = p_restaurant_id
       AND product.is_active = true
       AND product.tracks_inventory = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Producto remoto no activo o no controla inventario: %',
        product_id
        USING ERRCODE = '23503';
    END IF;

    target_quantity := quantity;
    base_unit_cost := purchase_unit_cost;

    IF purchase_unit_id IS NOT NULL THEN
      IF product_row.purchase_unit_id IS NULL
         OR product_row.inventory_unit_id IS NULL
         OR product_row.purchase_to_inventory_factor IS NULL
         OR product_row.purchase_to_inventory_factor <= 0 THEN
        RAISE EXCEPTION 'Producto sin conversion de unidad de compra: %',
          product_id
          USING ERRCODE = '23514';
      END IF;

      IF purchase_unit_id <> product_row.purchase_unit_id THEN
        RAISE EXCEPTION 'Unidad de compra no coincide para producto: %',
          product_id
          USING ERRCODE = '23514';
      END IF;

      target_quantity := quantity * product_row.purchase_to_inventory_factor;
      base_unit_cost :=
        purchase_unit_cost / product_row.purchase_to_inventory_factor;
    END IF;

    IF target_quantity <= 0 THEN
      RAISE EXCEPTION 'Cantidad base de producto invalida'
        USING ERRCODE = '23514';
    END IF;

    movement_id := COALESCE(
      NULLIF(item_payload ->> 'movement_id', ''),
      gen_random_uuid()::text
    );

    PERFORM public.apply_inventory_movement(
      movement_id,
      p_restaurant_id,
      product_id,
      'purchase',
      target_quantity,
      'admin_batch_purchase',
      movement_id,
      auth.uid()::text,
      NULL,
      now(),
      base_unit_cost
    );

    UPDATE public.products
       SET cost = purchase_unit_cost,
           updated_at = now()
     WHERE id = product_id
       AND restaurant_id = p_restaurant_id;

    item_count := item_count + 1;
  END LOOP;

  IF item_count = 0 THEN
    RAISE EXCEPTION 'No hay productos para registrar'
      USING ERRCODE = '23514';
  END IF;

  RETURN jsonb_build_object('item_count', item_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_recipe_unit_cost(
  p_restaurant_id uuid,
  p_product_id uuid
)
RETURNS numeric
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH RECURSIVE recipe_tree AS (
    SELECT
      line.component_product_id,
      (
        line.quantity *
        (1 + (line.waste_percent / 100)) *
        line_unit.base_factor /
        inventory_unit.base_factor
      )::numeric AS required_base_qty,
      1 AS depth,
      ARRAY[p_product_id, line.component_product_id] AS path
    FROM public.product_recipes recipe
    JOIN public.product_recipe_lines line
      ON line.recipe_id = recipe.id
     AND line.restaurant_id = recipe.restaurant_id
     AND line.is_active = true
    JOIN public.products component
      ON component.id = line.component_product_id
     AND component.restaurant_id = p_restaurant_id
     AND component.is_active = true
    JOIN public.measurement_units line_unit
      ON line_unit.id = line.unit_id
     AND (line_unit.restaurant_id IS NULL
          OR line_unit.restaurant_id = p_restaurant_id)
     AND line_unit.is_active = true
    JOIN public.measurement_units inventory_unit
      ON inventory_unit.id = component.inventory_unit_id
     AND (inventory_unit.restaurant_id IS NULL
          OR inventory_unit.restaurant_id = p_restaurant_id)
     AND inventory_unit.is_active = true
     AND inventory_unit.unit_group = line_unit.unit_group
    WHERE recipe.restaurant_id = p_restaurant_id
      AND recipe.product_id = p_product_id
      AND recipe.status = 'active'

    UNION ALL

    SELECT
      line.component_product_id,
      (
        tree.required_base_qty *
        line.quantity *
        (1 + (line.waste_percent / 100)) *
        line_unit.base_factor /
        inventory_unit.base_factor
      )::numeric AS required_base_qty,
      tree.depth + 1,
      tree.path || line.component_product_id
    FROM recipe_tree tree
    JOIN public.products parent_component
      ON parent_component.id = tree.component_product_id
     AND parent_component.restaurant_id = p_restaurant_id
     AND parent_component.uses_recipe = true
    JOIN public.product_recipes recipe
      ON recipe.restaurant_id = p_restaurant_id
     AND recipe.product_id = parent_component.id
     AND recipe.status = 'active'
    JOIN public.product_recipe_lines line
      ON line.recipe_id = recipe.id
     AND line.restaurant_id = recipe.restaurant_id
     AND line.is_active = true
    JOIN public.products component
      ON component.id = line.component_product_id
     AND component.restaurant_id = p_restaurant_id
     AND component.is_active = true
    JOIN public.measurement_units line_unit
      ON line_unit.id = line.unit_id
     AND (line_unit.restaurant_id IS NULL
          OR line_unit.restaurant_id = p_restaurant_id)
     AND line_unit.is_active = true
    JOIN public.measurement_units inventory_unit
      ON inventory_unit.id = component.inventory_unit_id
     AND (inventory_unit.restaurant_id IS NULL
          OR inventory_unit.restaurant_id = p_restaurant_id)
     AND inventory_unit.is_active = true
     AND inventory_unit.unit_group = line_unit.unit_group
    WHERE tree.depth < 20
      AND NOT line.component_product_id = ANY(tree.path)
  )
  SELECT COALESCE(
    SUM(
      tree.required_base_qty *
      CASE
        WHEN component.purchase_to_inventory_factor IS NOT NULL
         AND component.purchase_to_inventory_factor > 0
        THEN component.cost / component.purchase_to_inventory_factor
        ELSE component.cost
      END
    ),
    0
  )
  FROM recipe_tree tree
  JOIN public.products component
    ON component.id = tree.component_product_id
   AND component.restaurant_id = p_restaurant_id
   AND component.product_kind = 'raw_material';
$$;

COMMENT ON FUNCTION public.app_recipe_unit_cost(uuid, uuid) IS
  'Returns recipe cost deriving raw material base cost from purchase-unit cost.';

COMMENT ON COLUMN public.products.cost IS
  'For sellable products this is product cost; for raw materials it is purchase-unit cost.';

REVOKE ALL ON FUNCTION public.apply_inventory_movement(
  text, uuid, uuid, text, numeric, text, text, text, text, timestamptz, numeric
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_inventory_movement(
  text, uuid, uuid, text, numeric, text, text, text, text, timestamptz, numeric
) TO authenticated;

REVOKE ALL ON FUNCTION public.app_register_inventory_purchase_batch(uuid, jsonb)
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_register_inventory_purchase_batch(uuid, jsonb)
TO authenticated;

REVOKE ALL ON FUNCTION public.app_recipe_unit_cost(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_recipe_unit_cost(uuid, uuid)
TO authenticated;
