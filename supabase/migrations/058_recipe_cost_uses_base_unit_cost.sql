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

COMMENT ON FUNCTION public.app_recipe_unit_cost(uuid, uuid) IS
  'Returns recipe unit cost using raw material cost stored in inventory/base unit.';
