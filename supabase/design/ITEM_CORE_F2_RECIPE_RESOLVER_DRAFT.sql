-- KIVO F2 / RECIPE RESOLVER (UNDEPLOYED REVIEW DRAFT)
-- Intended for recipe tables migrated to item_id/component_item_id in F2.
-- Reuses product_recipes/product_recipe_lines; no extra recipe master.
-- No DML. Produces individual leaf consumption snapshots per sold line,
-- including nested recipe/version lineage. The POS transaction must persist
-- snapshots and post inventory moves in the SAME transaction.
-- No implicit raw-material negative stock. No silent cycle truncation.

CREATE OR REPLACE FUNCTION public.resolve_item_recipe_consumption(
  p_restaurant_id uuid,
  p_sale_lines jsonb,
  p_at timestamptz
)
RETURNS TABLE(
  sale_line_id uuid,
  root_item_id uuid,
  component_item_id uuid,
  quantity_base numeric,
  unit_cost_base numeric,
  recipe_trace jsonb
)
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_line jsonb;
  v_node jsonb;
  v_queue jsonb := '[]'::jsonb;
  v_item public.items;
  v_component public.items;
  v_recipe public.product_recipes;
  v_recipe_line public.product_recipe_lines;
  v_unit public.measurement_units;
  v_base public.measurement_units;
  v_qty numeric;
  v_child_qty numeric;
  v_item_id uuid;
  v_root uuid;
  v_line_id uuid;
  v_path jsonb;
  v_trace jsonb;
  v_nodes_processed integer := 0;
BEGIN
  IF p_restaurant_id IS NULL OR
     p_restaurant_id IS DISTINCT FROM public.current_restaurant_id()
  THEN
    RAISE EXCEPTION 'recipe_tenant_not_authorized'
      USING ERRCODE='42501';
  END IF;
  IF p_sale_lines IS NULL OR jsonb_typeof(p_sale_lines)<>'array'
     OR jsonb_array_length(p_sale_lines)=0 OR p_at IS NULL THEN
    RAISE EXCEPTION 'invalid_recipe_sale_lines'
      USING ERRCODE='22023';
  END IF;

  FOR v_line IN SELECT value FROM jsonb_array_elements(p_sale_lines)
  LOOP
    v_line_id := NULLIF(v_line->>'line_id','')::uuid;
    v_item_id := NULLIF(v_line->>'item_id','')::uuid;
    v_qty := NULLIF(v_line->>'quantity','')::numeric;
    IF v_line_id IS NULL OR v_item_id IS NULL OR v_qty IS NULL
       OR v_qty<=0 OR v_qty>1000000 THEN
      RAISE EXCEPTION 'invalid_recipe_sale_line'
        USING ERRCODE='22023';
    END IF;
    SELECT * INTO v_item FROM public.items i
    WHERE i.id=v_item_id AND i.restaurant_id=p_restaurant_id
      AND i.is_active AND i.can_sell;
    IF v_item.id IS NULL THEN
      RAISE EXCEPTION 'recipe_root_not_sellable_or_missing'
        USING ERRCODE='23503';
    END IF;

    IF v_item.uses_recipe THEN
      v_queue := v_queue || jsonb_build_array(jsonb_build_object(
        'line_id',v_line_id,'root_id',v_item_id,'item_id',v_item_id,
        'quantity',v_qty,'path',jsonb_build_array(v_item_id),
        'trace','[]'::jsonb
      ));
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_sale_lines) l
    GROUP BY (l->>'line_id')::uuid HAVING count(*)>1
  ) THEN
    RAISE EXCEPTION 'duplicate_recipe_sale_line_id'
      USING ERRCODE='23514';
  END IF;

  WHILE jsonb_array_length(v_queue)>0 LOOP
    v_nodes_processed := v_nodes_processed+1;
    IF v_nodes_processed>2000 THEN
      RAISE EXCEPTION 'recipe_expansion_limit_exceeded'
        USING ERRCODE='23514';
    END IF;
    v_node := v_queue -> (jsonb_array_length(v_queue)-1);
    v_queue := v_queue - (jsonb_array_length(v_queue)-1);

    v_line_id := (v_node->>'line_id')::uuid;
    v_root := (v_node->>'root_id')::uuid;
    v_item_id := (v_node->>'item_id')::uuid;
    v_qty := (v_node->>'quantity')::numeric;
    v_path := v_node->'path';
    v_trace := v_node->'trace';

    SELECT * INTO v_item FROM public.items i
    WHERE i.id=v_item_id AND i.restaurant_id=p_restaurant_id
      AND i.is_active=true;
    IF v_item.id IS NULL THEN
      RAISE EXCEPTION 'recipe_component_not_found_or_inactive'
        USING ERRCODE='23503';
    END IF;

    IF NOT v_item.uses_recipe THEN
      IF v_qty IS NULL OR v_qty<=0 OR v_qty>1000000000
         OR round(v_qty,6)<=0 THEN
        RAISE EXCEPTION 'invalid_recipe_leaf_quantity'
          USING ERRCODE='23514';
      END IF;
      sale_line_id := v_line_id;
      root_item_id := v_root;
      component_item_id := v_item_id;
      quantity_base := round(v_qty,6);
      unit_cost_base := v_item.base_unit_cost;
      recipe_trace := v_trace;
      RETURN NEXT;
      CONTINUE;
    END IF;

    IF jsonb_array_length(v_path)>20 THEN
      RAISE EXCEPTION 'recipe_depth_limit_exceeded'
        USING ERRCODE='23514';
    END IF;

    SELECT * INTO v_recipe
    FROM public.product_recipes recipe
    WHERE recipe.restaurant_id=p_restaurant_id
      AND recipe.item_id=v_item_id AND recipe.status='active'
      AND recipe.effective_from<=p_at
    ORDER BY recipe.version DESC LIMIT 1;
    IF v_recipe.id IS NULL THEN
      RAISE EXCEPTION 'active_recipe_missing_for_item'
        USING ERRCODE='23503';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.product_recipe_lines l
      WHERE l.restaurant_id=p_restaurant_id
        AND l.recipe_id=v_recipe.id AND l.is_active=true
    ) THEN
      RAISE EXCEPTION 'active_recipe_without_components'
        USING ERRCODE='23514';
    END IF;

    FOR v_recipe_line IN SELECT * FROM public.product_recipe_lines l
      WHERE l.restaurant_id=p_restaurant_id
        AND l.recipe_id=v_recipe.id AND l.is_active=true
      ORDER BY l.display_order,l.id
    LOOP
      SELECT * INTO v_component FROM public.items i
      WHERE i.id=v_recipe_line.component_item_id
        AND i.restaurant_id=p_restaurant_id AND i.is_active=true;
      IF v_component.id IS NULL THEN
        RAISE EXCEPTION 'recipe_component_not_found_or_inactive'
          USING ERRCODE='23503';
      END IF;
      SELECT * INTO v_unit FROM public.measurement_units u
      WHERE u.id=v_recipe_line.unit_id AND u.is_active
        AND (u.restaurant_id IS NULL OR u.restaurant_id=p_restaurant_id);
      SELECT * INTO v_base FROM public.measurement_units u
      WHERE u.id=v_component.base_unit_id AND u.is_active
        AND (u.restaurant_id IS NULL OR u.restaurant_id=p_restaurant_id);
      IF v_unit.id IS NULL OR v_base.id IS NULL
         OR v_unit.unit_group IS DISTINCT FROM v_base.unit_group
         OR v_unit.base_factor<=0 OR v_base.base_factor<=0 THEN
        RAISE EXCEPTION 'recipe_component_unit_incompatible'
          USING ERRCODE='23514';
      END IF;
      IF v_path @> jsonb_build_array(v_component.id) THEN
        RAISE EXCEPTION 'recipe_cycle_detected'
          USING ERRCODE='23514';
      END IF;
      v_child_qty := v_qty * v_recipe_line.quantity
        * (1+v_recipe_line.waste_percent/100)
        * v_unit.base_factor/v_base.base_factor;
      IF v_child_qty<=0 OR v_child_qty>1000000000 THEN
        RAISE EXCEPTION 'invalid_recipe_expanded_quantity'
          USING ERRCODE='23514';
      END IF;
      v_queue := v_queue || jsonb_build_array(jsonb_build_object(
        'line_id',v_line_id,'root_id',v_root,
        'item_id',v_component.id,'quantity',v_child_qty,
        'path',v_path || jsonb_build_array(v_component.id),
        'trace',v_trace || jsonb_build_array(jsonb_build_object(
          'recipe_id',v_recipe.id,'version',v_recipe.version
        ))
      ));
    END LOOP;
  END LOOP;
  RETURN;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_item_recipe_consumption(
  uuid,jsonb,timestamptz
) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.resolve_item_recipe_consumption(
  uuid,jsonb,timestamptz
) TO authenticated;
