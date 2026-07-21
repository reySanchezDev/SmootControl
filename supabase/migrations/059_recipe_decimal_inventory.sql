-- Aligns recipe inventory with decimal base-unit quantities.
-- Raw materials can be consumed in grams/ounces with waste percentages, so
-- movement and stock quantities must preserve decimals instead of rounding.

ALTER TABLE public.inventory_stock
  ALTER COLUMN quantity_on_hand TYPE numeric(18, 6)
  USING quantity_on_hand::numeric;

ALTER TABLE public.inventory_movements
  ALTER COLUMN quantity_delta TYPE numeric(18, 6)
  USING quantity_delta::numeric;

CREATE OR REPLACE FUNCTION public.pos_apply_recipe_inventory_movements(
  p_restaurant_id uuid,
  p_sale_id uuid,
  p_reference_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  movement_row record;
  current_quantity numeric(18, 6);
  next_quantity numeric(18, 6);
  allow_negative boolean;
  inserted_count integer := 0;
BEGIN
  allow_negative := public.app_allows_raw_recipe_negative_stock(
    p_restaurant_id
  );

  FOR movement_row IN
    WITH RECURSIVE recipe_tree AS (
      SELECT item.id AS sale_item_id,
             line.component_product_id,
             (
               item.quantity * line.quantity *
               (1 + (line.waste_percent / 100)) *
               line_unit.base_factor / inventory_unit.base_factor
             )::numeric(18, 6) AS required_base_qty,
             1 AS depth,
             ARRAY[sold.id, line.component_product_id] AS path
      FROM public.sale_items item
      JOIN public.products sold ON sold.id = item.product_id
       AND sold.restaurant_id = p_restaurant_id
       AND sold.uses_recipe = true
      JOIN public.product_recipes recipe ON recipe.restaurant_id = p_restaurant_id
       AND recipe.product_id = sold.id
       AND recipe.status = 'active'
      JOIN public.product_recipe_lines line ON line.recipe_id = recipe.id
       AND line.restaurant_id = recipe.restaurant_id
       AND line.is_active = true
      JOIN public.products component ON component.id = line.component_product_id
       AND component.restaurant_id = p_restaurant_id
       AND component.is_active = true
      JOIN public.measurement_units line_unit ON line_unit.id = line.unit_id
       AND (line_unit.restaurant_id IS NULL
            OR line_unit.restaurant_id = p_restaurant_id)
       AND line_unit.is_active = true
      JOIN public.measurement_units inventory_unit
        ON inventory_unit.id = component.inventory_unit_id
       AND (inventory_unit.restaurant_id IS NULL
            OR inventory_unit.restaurant_id = p_restaurant_id)
       AND inventory_unit.is_active = true
       AND inventory_unit.unit_group = line_unit.unit_group
      WHERE item.sale_id = p_sale_id

      UNION ALL

      SELECT tree.sale_item_id,
             line.component_product_id,
             (
               tree.required_base_qty * line.quantity *
               (1 + (line.waste_percent / 100)) *
               line_unit.base_factor / inventory_unit.base_factor
             )::numeric(18, 6) AS required_base_qty,
             tree.depth + 1,
             tree.path || line.component_product_id
      FROM recipe_tree tree
      JOIN public.products parent_component
        ON parent_component.id = tree.component_product_id
       AND parent_component.restaurant_id = p_restaurant_id
       AND parent_component.uses_recipe = true
      JOIN public.product_recipes recipe ON recipe.restaurant_id = p_restaurant_id
       AND recipe.product_id = parent_component.id
       AND recipe.status = 'active'
      JOIN public.product_recipe_lines line ON line.recipe_id = recipe.id
       AND line.restaurant_id = recipe.restaurant_id
       AND line.is_active = true
      JOIN public.products component ON component.id = line.component_product_id
       AND component.restaurant_id = p_restaurant_id
       AND component.is_active = true
      JOIN public.measurement_units line_unit ON line_unit.id = line.unit_id
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
    ),
    raw_requirements AS (
      SELECT tree.sale_item_id,
             tree.component_product_id,
             ROUND(SUM(tree.required_base_qty), 6) AS consumed_qty
      FROM recipe_tree tree
      JOIN public.products component ON component.id = tree.component_product_id
       AND component.restaurant_id = p_restaurant_id
       AND component.product_kind = 'raw_material'
       AND component.tracks_inventory = true
      GROUP BY tree.sale_item_id, tree.component_product_id
    )
    SELECT 'recipe:' || p_sale_id || ':' || sale_item_id || ':'
             || component_product_id AS movement_id,
           component_product_id,
           -consumed_qty AS quantity_delta
    FROM raw_requirements
    WHERE consumed_qty > 0
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.inventory_movements
      WHERE id = movement_row.movement_id
    ) THEN
      CONTINUE;
    END IF;

    INSERT INTO public.inventory_stock (
      restaurant_id, product_id, quantity_on_hand, created_at, updated_at
    )
    VALUES (p_restaurant_id, movement_row.component_product_id, 0, now(), now())
    ON CONFLICT (restaurant_id, product_id) DO NOTHING;

    SELECT quantity_on_hand INTO current_quantity
    FROM public.inventory_stock
    WHERE restaurant_id = p_restaurant_id
      AND product_id = movement_row.component_product_id
    FOR UPDATE;

    next_quantity := current_quantity + movement_row.quantity_delta;
    IF next_quantity < 0 AND allow_negative = false THEN
      RAISE EXCEPTION 'Stock insuficiente para materia prima de receta'
        USING ERRCODE = '23514';
    END IF;

    INSERT INTO public.inventory_movements (
      id, restaurant_id, product_id, movement_type, quantity_delta,
      reference_type, reference_id, user_id, notes, created_at
    )
    SELECT movement_row.movement_id, p_restaurant_id,
           movement_row.component_product_id, 'recipe_consumption',
           movement_row.quantity_delta, p_reference_type, p_sale_id::text,
           sale.user_id::text, 'Consumo automatico por receta', sale.sold_at
    FROM public.sales sale
    WHERE sale.id = p_sale_id
      AND sale.restaurant_id = p_restaurant_id;

    UPDATE public.inventory_stock
    SET quantity_on_hand = next_quantity,
        updated_at = now()
    WHERE restaurant_id = p_restaurant_id
      AND product_id = movement_row.component_product_id;

    inserted_count := inserted_count + 1;
  END LOOP;

  RETURN jsonb_build_object('inserted_movements', inserted_count);
END;
$$;

CREATE OR REPLACE FUNCTION public.pos_reverse_recipe_inventory_movements(
  p_restaurant_id uuid,
  p_sale_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  original_movement record;
  current_quantity numeric(18, 6);
  next_quantity numeric(18, 6);
  inserted_count integer := 0;
BEGIN
  FOR original_movement IN
    SELECT id, product_id, quantity_delta, user_id
    FROM public.inventory_movements
    WHERE restaurant_id = p_restaurant_id
      AND reference_id = p_sale_id::text
      AND movement_type = 'recipe_consumption'
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.inventory_movements
      WHERE id = 'recipe_void:' || original_movement.id
    ) THEN
      CONTINUE;
    END IF;

    INSERT INTO public.inventory_stock (
      restaurant_id, product_id, quantity_on_hand, created_at, updated_at
    )
    VALUES (p_restaurant_id, original_movement.product_id, 0, now(), now())
    ON CONFLICT (restaurant_id, product_id) DO NOTHING;

    SELECT quantity_on_hand INTO current_quantity
    FROM public.inventory_stock
    WHERE restaurant_id = p_restaurant_id
      AND product_id = original_movement.product_id
    FOR UPDATE;

    next_quantity := current_quantity - original_movement.quantity_delta;

    INSERT INTO public.inventory_movements (
      id, restaurant_id, product_id, movement_type, quantity_delta,
      reference_type, reference_id, user_id, notes, created_at
    )
    VALUES (
      'recipe_void:' || original_movement.id, p_restaurant_id,
      original_movement.product_id, 'sale_void',
      -original_movement.quantity_delta, 'sale_void', p_sale_id::text,
      original_movement.user_id, 'Reintegro automatico por anulacion de receta',
      now()
    );

    UPDATE public.inventory_stock
    SET quantity_on_hand = next_quantity,
        updated_at = now()
    WHERE restaurant_id = p_restaurant_id
      AND product_id = original_movement.product_id;

    inserted_count := inserted_count + 1;
  END LOOP;

  RETURN jsonb_build_object('inserted_movements', inserted_count);
END;
$$;

