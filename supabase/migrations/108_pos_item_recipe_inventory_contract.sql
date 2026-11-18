-- Move POS recipe cost and stock consumption to the canonical item model.
BEGIN;

UPDATE public.items i
SET uses_recipe = p.uses_recipe,
    send_to_kitchen = p.send_to_kitchen,
    is_active = p.is_active,
    updated_at = now()
FROM public.products p
WHERE p.id = i.id AND p.restaurant_id = i.restaurant_id
  AND (i.uses_recipe IS DISTINCT FROM p.uses_recipe
    OR i.send_to_kitchen IS DISTINCT FROM p.send_to_kitchen
    OR i.is_active IS DISTINCT FROM p.is_active);

INSERT INTO public.item_recipes(
  id, restaurant_id, item_id, version, status, created_at
)
SELECT r.id, r.restaurant_id, r.product_id, r.version, r.status, r.created_at
FROM public.product_recipes r
JOIN public.items i ON i.id = r.product_id
 AND i.restaurant_id = r.restaurant_id
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.item_recipe_lines(
  id, restaurant_id, recipe_id, component_item_id, unit_id, quantity,
  waste_percent, display_order, is_active
)
SELECT l.id, l.restaurant_id, l.recipe_id, l.component_product_id, l.unit_id,
  l.quantity, l.waste_percent, l.display_order, l.is_active
FROM public.product_recipe_lines l
JOIN public.item_recipes r ON r.id = l.recipe_id
JOIN public.items i ON i.id = l.component_product_id
 AND i.restaurant_id = l.restaurant_id
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.app_recipe_unit_cost(
  p_restaurant_id uuid, p_product_id uuid
) RETURNS numeric LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  WITH RECURSIVE recipe_tree(component_item_id, required_base_qty, depth, path) AS (
    SELECT line.component_item_id,
      (line.quantity * (1 + line.waste_percent / 100)
        * COALESCE(unit.quantity_in_base, 1))::numeric,
      1, ARRAY[p_product_id, line.component_item_id]
    FROM public.item_recipes recipe
    JOIN public.item_recipe_lines line ON line.recipe_id = recipe.id
      AND line.restaurant_id = recipe.restaurant_id AND line.is_active
    LEFT JOIN public.item_units unit ON unit.restaurant_id = line.restaurant_id
      AND unit.item_id = line.component_item_id AND unit.unit_id = line.unit_id
      AND unit.is_active
    WHERE recipe.restaurant_id = p_restaurant_id
      AND recipe.item_id = p_product_id AND recipe.status = 'active'
    UNION ALL
    SELECT line.component_item_id,
      (tree.required_base_qty * line.quantity
        * (1 + line.waste_percent / 100)
        * COALESCE(unit.quantity_in_base, 1))::numeric,
      tree.depth + 1, tree.path || line.component_item_id
    FROM recipe_tree tree
    JOIN public.item_recipes recipe ON recipe.restaurant_id = p_restaurant_id
      AND recipe.item_id = tree.component_item_id AND recipe.status = 'active'
    JOIN public.item_recipe_lines line ON line.recipe_id = recipe.id
      AND line.restaurant_id = recipe.restaurant_id AND line.is_active
    LEFT JOIN public.item_units unit ON unit.restaurant_id = line.restaurant_id
      AND unit.item_id = line.component_item_id AND unit.unit_id = line.unit_id
      AND unit.is_active
    WHERE tree.depth < 20 AND NOT line.component_item_id = ANY(tree.path)
  )
  SELECT COALESCE(SUM(tree.required_base_qty * item.base_unit_cost), 0)
  FROM recipe_tree tree
  JOIN public.items item ON item.id = tree.component_item_id
    AND item.restaurant_id = p_restaurant_id
    AND item.tracks_inventory;
$$;

CREATE OR REPLACE FUNCTION public.app_recipe_component_expands_to(
  p_restaurant_id uuid, p_start_product_id uuid, p_target_product_id uuid
) RETURNS boolean LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  WITH RECURSIVE recipe_tree(component_item_id, depth, path) AS (
    SELECT line.component_item_id, 1, ARRAY[line.component_item_id]
    FROM public.item_recipes recipe
    JOIN public.item_recipe_lines line ON line.recipe_id = recipe.id
      AND line.restaurant_id = recipe.restaurant_id AND line.is_active
    WHERE recipe.restaurant_id = p_restaurant_id
      AND recipe.item_id = p_start_product_id AND recipe.status = 'active'
    UNION ALL
    SELECT line.component_item_id, tree.depth + 1,
      tree.path || line.component_item_id
    FROM recipe_tree tree
    JOIN public.item_recipes recipe ON recipe.restaurant_id = p_restaurant_id
      AND recipe.item_id = tree.component_item_id AND recipe.status = 'active'
    JOIN public.item_recipe_lines line ON line.recipe_id = recipe.id
      AND line.restaurant_id = recipe.restaurant_id AND line.is_active
    WHERE tree.depth < 20 AND NOT line.component_item_id = ANY(tree.path)
  )
  SELECT EXISTS (
    SELECT 1 FROM recipe_tree WHERE component_item_id = p_target_product_id
  );
$$;

CREATE OR REPLACE FUNCTION public.pos_apply_recipe_inventory_movements(
  p_restaurant_id uuid, p_sale_id uuid, p_reference_type text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  movement_row record;
  inserted_count integer := 0;
  sale_user text;
BEGIN
  SELECT user_id::text INTO sale_user FROM public.sales
  WHERE id = p_sale_id AND restaurant_id = p_restaurant_id;
  FOR movement_row IN
    WITH RECURSIVE recipe_tree(sale_item_id, component_item_id,
        required_base_qty, depth, path) AS (
      SELECT sold_line.id, line.component_item_id,
        (sold_line.quantity * line.quantity
          * (1 + line.waste_percent / 100)
          * COALESCE(unit.quantity_in_base, 1))::numeric,
        1, ARRAY[sold.id, line.component_item_id]
      FROM public.sale_items sold_line
      JOIN public.items sold ON sold.id = sold_line.item_id
        AND sold.restaurant_id = p_restaurant_id AND sold.uses_recipe
      JOIN public.item_recipes recipe ON recipe.item_id = sold.id
        AND recipe.restaurant_id = p_restaurant_id AND recipe.status = 'active'
      JOIN public.item_recipe_lines line ON line.recipe_id = recipe.id
        AND line.restaurant_id = recipe.restaurant_id AND line.is_active
      LEFT JOIN public.item_units unit ON unit.restaurant_id = line.restaurant_id
        AND unit.item_id = line.component_item_id AND unit.unit_id = line.unit_id
        AND unit.is_active
      WHERE sold_line.sale_id = p_sale_id
      UNION ALL
      SELECT tree.sale_item_id, line.component_item_id,
        (tree.required_base_qty * line.quantity
          * (1 + line.waste_percent / 100)
          * COALESCE(unit.quantity_in_base, 1))::numeric,
        tree.depth + 1, tree.path || line.component_item_id
      FROM recipe_tree tree
      JOIN public.item_recipes recipe ON recipe.item_id = tree.component_item_id
        AND recipe.restaurant_id = p_restaurant_id AND recipe.status = 'active'
      JOIN public.item_recipe_lines line ON line.recipe_id = recipe.id
        AND line.restaurant_id = recipe.restaurant_id AND line.is_active
      LEFT JOIN public.item_units unit ON unit.restaurant_id = line.restaurant_id
        AND unit.item_id = line.component_item_id AND unit.unit_id = line.unit_id
        AND unit.is_active
      WHERE tree.depth < 20 AND NOT line.component_item_id = ANY(tree.path)
    ), requirements AS (
      SELECT sale_item_id, component_item_id,
        round(sum(required_base_qty), 6) AS consumed_qty
      FROM recipe_tree GROUP BY sale_item_id, component_item_id
    )
    SELECT 'recipe:' || p_sale_id || ':' || sale_item_id || ':'
      || component_item_id AS movement_id, component_item_id,
      -consumed_qty AS quantity_delta
    FROM requirements
    JOIN public.items component ON component.id = requirements.component_item_id
      AND component.restaurant_id = p_restaurant_id
      AND component.tracks_inventory AND component.is_active
    WHERE consumed_qty > 0
  LOOP
    IF EXISTS (SELECT 1 FROM public.inventory_movements
      WHERE id = movement_row.movement_id) THEN CONTINUE; END IF;
    PERFORM public.apply_inventory_movement_v2(
      movement_row.movement_id, p_restaurant_id, movement_row.component_item_id,
      NULL, 'recipe_consumption', movement_row.quantity_delta,
      p_reference_type, p_sale_id::text, sale_user,
      'Consumo automatico por receta', now(), 0
    );
    inserted_count := inserted_count + 1;
  END LOOP;
  RETURN jsonb_build_object('inserted_movements', inserted_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_reverse_recipe_inventory_movements(
  p_restaurant_id uuid, p_sale_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE movement_row record; inserted_count integer := 0;
BEGIN
  FOR movement_row IN SELECT id, item_id, quantity_delta, user_id
    FROM public.inventory_movements
    WHERE restaurant_id = p_restaurant_id AND reference_id = p_sale_id::text
      AND movement_type = 'recipe_consumption' AND item_id IS NOT NULL
  LOOP
    IF EXISTS (SELECT 1 FROM public.inventory_movements
      WHERE id = 'recipe_void:' || movement_row.id) THEN CONTINUE; END IF;
    PERFORM public.apply_inventory_movement_v2(
      'recipe_void:' || movement_row.id, p_restaurant_id, movement_row.item_id,
      NULL, 'sale_void', -movement_row.quantity_delta, 'sale_void',
      p_sale_id::text, movement_row.user_id, 'Reintegro automatico por receta',
      now(), 0
    );
    inserted_count := inserted_count + 1;
  END LOOP;
  RETURN jsonb_build_object('inserted_movements', inserted_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_update_sale_recipe_costs(
  p_restaurant_id uuid, p_sale_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE item_row record; recipe_cost numeric; updated_count integer := 0;
BEGIN
  FOR item_row IN SELECT line.id, line.item_id, line.quantity, line.unit_price
    FROM public.sale_items line JOIN public.items item ON item.id = line.item_id
    WHERE line.sale_id = p_sale_id AND item.restaurant_id = p_restaurant_id
      AND item.uses_recipe
  LOOP
    recipe_cost := public.app_recipe_unit_cost(p_restaurant_id, item_row.item_id);
    UPDATE public.sale_items SET unit_cost = recipe_cost,
      gross_profit = (item_row.quantity * item_row.unit_price)
        - (item_row.quantity * recipe_cost)
      WHERE id = item_row.id;
    updated_count := updated_count + 1;
  END LOOP;
  UPDATE public.sales SET total_cost = (SELECT coalesce(sum(quantity * unit_cost), 0)
    FROM public.sale_items WHERE sale_id = p_sale_id), updated_at = now()
    WHERE id = p_sale_id AND restaurant_id = p_restaurant_id;
  UPDATE public.sales SET gross_profit = total_amount - total_cost
    WHERE id = p_sale_id AND restaurant_id = p_restaurant_id;
  RETURN jsonb_build_object('updated_items', updated_count);
END;
$$;

REVOKE ALL ON FUNCTION public.app_recipe_unit_cost(uuid,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_recipe_component_expands_to(uuid,uuid,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_apply_recipe_inventory_movements(uuid,uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_reverse_recipe_inventory_movements(uuid,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_update_sale_recipe_costs(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pos_apply_recipe_inventory_movements(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pos_reverse_recipe_inventory_movements(uuid,uuid) TO authenticated;
COMMIT;
