-- Updates sale item historical costs from active recipes during POS sync.

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
  SELECT COALESCE(SUM(tree.required_base_qty * component.cost), 0)
  FROM recipe_tree tree
  JOIN public.products component
    ON component.id = tree.component_product_id
   AND component.restaurant_id = p_restaurant_id
   AND component.product_kind = 'raw_material';
$$;

CREATE OR REPLACE FUNCTION public.pos_update_sale_recipe_costs(
  p_restaurant_id uuid,
  p_sale_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item_row record;
  recipe_cost numeric;
  updated_count integer := 0;
  v_total_cost numeric := 0;
BEGIN
  FOR item_row IN
    SELECT item.id, item.product_id, item.quantity, item.unit_price
      FROM public.sale_items item
      JOIN public.products product
        ON product.id = item.product_id
       AND product.restaurant_id = p_restaurant_id
       AND product.uses_recipe = true
     WHERE item.sale_id = p_sale_id
  LOOP
    recipe_cost := public.app_recipe_unit_cost(
      p_restaurant_id,
      item_row.product_id
    );

    IF recipe_cost > 0 THEN
      UPDATE public.sale_items
         SET unit_cost = recipe_cost,
             gross_profit =
               (item_row.quantity * item_row.unit_price) -
               (item_row.quantity * recipe_cost)
       WHERE id = item_row.id;
      updated_count := updated_count + 1;
    END IF;
  END LOOP;

  SELECT COALESCE(SUM(quantity * unit_cost), 0)
    INTO v_total_cost
    FROM public.sale_items
   WHERE sale_id = p_sale_id;

  UPDATE public.sales
     SET total_cost = v_total_cost,
         gross_profit = total_amount - v_total_cost,
         updated_at = now()
   WHERE id = p_sale_id
     AND restaurant_id = p_restaurant_id;

  RETURN jsonb_build_object('updated_items', updated_count);
END;
$$;

ALTER FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
RENAME TO pos_sync_sale_recipe_cost_base_20260716;

CREATE OR REPLACE FUNCTION public.pos_sync_sale(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  synced_sale_id uuid;
BEGIN
  result := public.pos_sync_sale_recipe_cost_base_20260716(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  synced_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF synced_sale_id IS NOT NULL THEN
    PERFORM public.pos_update_sale_recipe_costs(
      p_restaurant_id,
      synced_sale_id
    );
  END IF;

  RETURN result;
END;
$$;

ALTER FUNCTION public.pos_sync_staff_consumption(uuid, uuid, text, jsonb)
RENAME TO pos_sync_staff_consumption_recipe_cost_base_20260716;

CREATE OR REPLACE FUNCTION public.pos_sync_staff_consumption(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  synced_sale_id uuid;
BEGIN
  result := public.pos_sync_staff_consumption_recipe_cost_base_20260716(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  synced_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF synced_sale_id IS NOT NULL THEN
    PERFORM public.pos_update_sale_recipe_costs(
      p_restaurant_id,
      synced_sale_id
    );
  END IF;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.app_recipe_unit_cost(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_update_sale_recipe_costs(uuid, uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_sync_staff_consumption(uuid, uuid, text, jsonb)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pos_sync_staff_consumption(
  uuid,
  uuid,
  text,
  jsonb
) TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.app_recipe_unit_cost(uuid, uuid) IS
  'Calculates one product recipe unit cost from raw material component costs.';

COMMENT ON FUNCTION public.pos_update_sale_recipe_costs(uuid, uuid) IS
  'Updates historical sale item costs and sale totals from active recipes after POS sync.';
