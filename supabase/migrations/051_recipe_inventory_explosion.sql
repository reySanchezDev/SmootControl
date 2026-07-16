-- Explodes active product recipes into raw-material inventory movements during
-- remote POS sync. V1 is non-blocking only when the business rule allows raw
-- material negative stock.

ALTER TABLE public.inventory_stock
  DROP CONSTRAINT IF EXISTS inventory_stock_quantity_on_hand_check;

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
      'recipe_consumption'
    )
  );

CREATE OR REPLACE FUNCTION public.app_allows_raw_recipe_negative_stock(
  p_restaurant_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((
    SELECT bool_value
      FROM public.business_rules
     WHERE restaurant_id = p_restaurant_id
       AND key = 'allow_raw_material_negative_stock_from_recipes'
     LIMIT 1
  ), true);
$$;

CREATE OR REPLACE FUNCTION public.pos_sale_payload_for_current_stock_rules(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sale_payload jsonb := COALESCE(p_payload -> 'sale', '{}'::jsonb);
  v_sales_type_id uuid :=
    NULLIF(sale_payload ->> 'sales_type_id', '')::uuid;
  inventory_payload jsonb;
  packaging_payload jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(movement.value), '[]'::jsonb)
    INTO inventory_payload
    FROM jsonb_array_elements(
      COALESCE(p_payload -> 'inventory_movements', '[]'::jsonb)
    ) AS movement(value)
    JOIN public.products product
      ON product.id = NULLIF(movement.value ->> 'product_id', '')::uuid
     AND product.restaurant_id = p_restaurant_id
   WHERE product.tracks_inventory = true
     AND product.uses_recipe = false;

  SELECT COALESCE(jsonb_agg(movement.value), '[]'::jsonb)
    INTO packaging_payload
    FROM jsonb_array_elements(
      COALESCE(p_payload -> 'packaging_movements', '[]'::jsonb)
    ) AS movement(value)
    JOIN public.packaging_items item
      ON item.id = NULLIF(movement.value ->> 'packaging_item_id', '')::uuid
     AND item.restaurant_id = p_restaurant_id
   WHERE item.is_active = true
     AND item.tracks_stock = true
     AND v_sales_type_id IS NOT NULL
     AND EXISTS (
       SELECT 1
         FROM jsonb_array_elements(
           COALESCE(p_payload -> 'items', '[]'::jsonb)
         ) AS sale_item(value)
         JOIN public.product_packaging_rules rule
           ON rule.product_id =
              NULLIF(sale_item.value ->> 'product_id', '')::uuid
          AND rule.restaurant_id = p_restaurant_id
        WHERE rule.sales_type_id = v_sales_type_id
          AND rule.packaging_item_id =
              NULLIF(movement.value ->> 'packaging_item_id', '')::uuid
          AND rule.is_active = true
     );

  RETURN jsonb_set(
    jsonb_set(
      p_payload,
      '{inventory_movements}',
      inventory_payload,
      true
    ),
    '{packaging_movements}',
    packaging_payload,
    true
  );
END;
$$;

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
  current_quantity integer;
  next_quantity integer;
  allow_negative boolean;
  inserted_count integer := 0;
BEGIN
  allow_negative := public.app_allows_raw_recipe_negative_stock(
    p_restaurant_id
  );

  FOR movement_row IN
    WITH RECURSIVE recipe_tree AS (
      SELECT
        item.id AS sale_item_id,
        line.component_product_id,
        (
          item.quantity *
          line.quantity *
          (1 + (line.waste_percent / 100)) *
          line_unit.base_factor /
          inventory_unit.base_factor
        )::numeric AS required_base_qty,
        1 AS depth,
        ARRAY[sold.id, line.component_product_id] AS path
      FROM public.sale_items item
      JOIN public.products sold
        ON sold.id = item.product_id
       AND sold.restaurant_id = p_restaurant_id
       AND sold.uses_recipe = true
      JOIN public.product_recipes recipe
        ON recipe.restaurant_id = p_restaurant_id
       AND recipe.product_id = sold.id
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
      WHERE item.sale_id = p_sale_id

      UNION ALL

      SELECT
        tree.sale_item_id,
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
    ),
    raw_requirements AS (
      SELECT
        tree.sale_item_id,
        tree.component_product_id,
        CEIL(SUM(tree.required_base_qty))::integer AS consumed_qty
      FROM recipe_tree tree
      JOIN public.products component
        ON component.id = tree.component_product_id
       AND component.restaurant_id = p_restaurant_id
       AND component.product_kind = 'raw_material'
       AND component.tracks_inventory = true
      GROUP BY tree.sale_item_id, tree.component_product_id
    )
    SELECT
      'recipe:' || p_sale_id || ':' || sale_item_id || ':'
        || component_product_id AS movement_id,
      component_product_id,
      -consumed_qty AS quantity_delta
    FROM raw_requirements
    WHERE consumed_qty > 0
    ORDER BY sale_item_id, component_product_id
  LOOP
    IF EXISTS (
      SELECT 1
        FROM public.inventory_movements
       WHERE id = movement_row.movement_id
    ) THEN
      CONTINUE;
    END IF;

    INSERT INTO public.inventory_stock (
      restaurant_id,
      product_id,
      quantity_on_hand,
      created_at,
      updated_at
    )
    VALUES (
      p_restaurant_id,
      movement_row.component_product_id,
      0,
      now(),
      now()
    )
    ON CONFLICT (restaurant_id, product_id) DO NOTHING;

    SELECT quantity_on_hand
      INTO current_quantity
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
      id,
      restaurant_id,
      product_id,
      movement_type,
      quantity_delta,
      reference_type,
      reference_id,
      user_id,
      notes,
      created_at
    )
    SELECT
      movement_row.movement_id,
      p_restaurant_id,
      movement_row.component_product_id,
      'recipe_consumption',
      movement_row.quantity_delta,
      p_reference_type,
      p_sale_id::text,
      sale.user_id::text,
      'Consumo automatico por receta',
      sale.sold_at
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

ALTER FUNCTION public.pos_sync_sale(uuid, uuid, text, jsonb)
RENAME TO pos_sync_sale_recipe_base_20260716;

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
  result := public.pos_sync_sale_recipe_base_20260716(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  synced_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF synced_sale_id IS NOT NULL THEN
    PERFORM public.pos_apply_recipe_inventory_movements(
      p_restaurant_id,
      synced_sale_id,
      'sale'
    );
  END IF;

  RETURN result;
END;
$$;

ALTER FUNCTION public.pos_sync_staff_consumption(uuid, uuid, text, jsonb)
RENAME TO pos_sync_staff_consumption_recipe_base_20260716;

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
  result := public.pos_sync_staff_consumption_recipe_base_20260716(
    p_restaurant_id,
    p_device_id,
    p_device_secret,
    p_payload
  );

  synced_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;
  IF synced_sale_id IS NOT NULL THEN
    PERFORM public.pos_apply_recipe_inventory_movements(
      p_restaurant_id,
      synced_sale_id,
      'staff_consumption'
    );
  END IF;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.app_allows_raw_recipe_negative_stock(uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pos_apply_recipe_inventory_movements(
  uuid,
  uuid,
  text
) FROM PUBLIC;
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

COMMENT ON FUNCTION public.pos_apply_recipe_inventory_movements(
  uuid,
  uuid,
  text
) IS
  'Creates idempotent raw-material inventory movements for active recipes after remote sale synchronization.';
