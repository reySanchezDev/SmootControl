-- Run in the same transaction after recipe fixture and resolver draft.
DO $$
DECLARE
  v_lines jsonb :=
    '[{"line_id":"60000000-0000-0000-0000-000000000001","item_id":"30000000-0000-0000-0000-000000000001","quantity":2}]';
  v_at timestamptz := '2026-11-10T19:00:00Z';
  v_rows integer;
  v_flour numeric;
  v_tomato numeric;
  v_total_cost numeric;
  v_versions integer;
BEGIN
  SELECT count(*),
    sum(quantity_base) FILTER(
      WHERE component_item_id='30000000-0000-0000-0000-000000000003'),
    sum(quantity_base) FILTER(
      WHERE component_item_id='30000000-0000-0000-0000-000000000004'),
    sum(quantity_base*unit_cost_base),
    max(jsonb_array_length(recipe_trace))
  INTO v_rows,v_flour,v_tomato,v_total_cost,v_versions
  FROM public.resolve_item_recipe_consumption(
    '00000000-0000-0000-0000-000000000001',v_lines,v_at
  );
  IF v_rows<>2 OR v_flour<>1000 OR v_tomato<>220
     OR v_total_cost<>14.4 OR v_versions<>2 THEN
    RAISE EXCEPTION
      'recipe_calculation_wrong: rows %, flour %, tomato %, cost %, versions %',
      v_rows,v_flour,v_tomato,v_total_cost,v_versions;
  END IF;

  -- A second sale line of same root must keep a separate source line ID.
  IF (
    SELECT count(DISTINCT sale_line_id)
    FROM public.resolve_item_recipe_consumption(
      '00000000-0000-0000-0000-000000000001',
      v_lines || jsonb_build_array(jsonb_build_object(
        'line_id','60000000-0000-0000-0000-000000000002',
        'item_id','30000000-0000-0000-0000-000000000001',
        'quantity',1
      )),v_at
    )
  )<>2 THEN RAISE EXCEPTION 'recipe_sale_line_identity_lost'; END IF;

  BEGIN
    PERFORM * FROM public.resolve_item_recipe_consumption(
      '00000000-0000-0000-0000-000000000001',
      v_lines || v_lines,v_at
    );
    RAISE EXCEPTION 'duplicate_recipe_line_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'duplicate_recipe_sale_line_id' THEN RAISE; END IF;
  END;

  -- A sauce in grams cannot be used as a count-unit preparation.
  UPDATE public.product_recipe_lines
  SET unit_id='10000000-0000-0000-0000-000000000002'
  WHERE id='50000000-0000-0000-0000-000000000002';
  BEGIN
    PERFORM * FROM public.resolve_item_recipe_consumption(
      '00000000-0000-0000-0000-000000000001',v_lines,v_at
    );
    RAISE EXCEPTION 'recipe_dimension_mismatch_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'recipe_component_unit_incompatible' THEN RAISE; END IF;
  END;
  UPDATE public.product_recipe_lines
  SET unit_id='10000000-0000-0000-0000-000000000001'
  WHERE id='50000000-0000-0000-0000-000000000002';

  UPDATE public.product_recipes SET status='inactive'
  WHERE id='40000000-0000-0000-0000-000000000002';
  BEGIN
    PERFORM * FROM public.resolve_item_recipe_consumption(
      '00000000-0000-0000-0000-000000000001',v_lines,v_at
    );
    RAISE EXCEPTION 'inactive_nested_recipe_not_rejected';
  EXCEPTION WHEN foreign_key_violation THEN
    IF SQLERRM <> 'active_recipe_missing_for_item' THEN RAISE; END IF;
  END;
  UPDATE public.product_recipes SET status='active'
  WHERE id='40000000-0000-0000-0000-000000000002';

  -- Introduce an intentional cycle burger -> sauce -> tomato -> burger.
  UPDATE public.items SET uses_recipe=true
    WHERE id='30000000-0000-0000-0000-000000000004';
  INSERT INTO public.product_recipes VALUES(
    '40000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000004',
    1,'active','2026-01-01T00:00:00Z');
  INSERT INTO public.product_recipe_lines VALUES(
    '50000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000001',1,
    '10000000-0000-0000-0000-000000000001',0,1,true);
  BEGIN
    PERFORM * FROM public.resolve_item_recipe_consumption(
      '00000000-0000-0000-0000-000000000001',v_lines,v_at
    );
    RAISE EXCEPTION 'recipe_cycle_not_rejected';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'recipe_cycle_detected' THEN RAISE; END IF;
  END;
  DELETE FROM public.product_recipe_lines
   WHERE id='50000000-0000-0000-0000-000000000004';
  DELETE FROM public.product_recipes
   WHERE id='40000000-0000-0000-0000-000000000003';
  UPDATE public.items SET uses_recipe=false
   WHERE id='30000000-0000-0000-0000-000000000004';

  BEGIN
    PERFORM * FROM public.resolve_item_recipe_consumption(
      '00000000-0000-0000-0000-000000000002',v_lines,v_at
    );
    RAISE EXCEPTION 'recipe_tenant_not_rejected';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'recipe_tenant_not_authorized' THEN RAISE; END IF;
  END;

  RAISE NOTICE 'PASS F2 recipe resolver: nested versions, units, waste, cost, source line, cycles, tenant';
END;
$$;
ROLLBACK;
