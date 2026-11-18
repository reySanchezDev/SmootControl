-- Canonical versioned recipes for item master V2. Independent from frozen 088.
-- Additive only; historical product_recipes remain unchanged.
BEGIN;

CREATE TABLE public.item_recipes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  item_id uuid NOT NULL,
  version integer NOT NULL CHECK (version > 0),
  status text NOT NULL CHECK (status IN ('active','inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, id),
  UNIQUE (restaurant_id, item_id, version),
  FOREIGN KEY (restaurant_id, item_id)
    REFERENCES public.items(restaurant_id, id)
);
CREATE UNIQUE INDEX item_recipes_active_uidx
  ON public.item_recipes(restaurant_id, item_id) WHERE status='active';

CREATE TABLE public.item_recipe_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL,
  recipe_id uuid NOT NULL,
  component_item_id uuid NOT NULL,
  unit_id uuid NOT NULL REFERENCES public.measurement_units(id),
  quantity numeric(18,6) NOT NULL CHECK (quantity > 0),
  waste_percent numeric(8,4) NOT NULL DEFAULT 0
    CHECK (waste_percent >= 0 AND waste_percent <= 100),
  display_order integer NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (restaurant_id, recipe_id, display_order),
  FOREIGN KEY (restaurant_id, recipe_id)
    REFERENCES public.item_recipes(restaurant_id, id),
  FOREIGN KEY (restaurant_id, component_item_id)
    REFERENCES public.items(restaurant_id, id)
);
CREATE INDEX item_recipe_lines_component_idx
  ON public.item_recipe_lines(restaurant_id, component_item_id);

ALTER TABLE public.item_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_recipe_lines ENABLE ROW LEVEL SECURITY;
CREATE POLICY item_recipes_read ON public.item_recipes FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_recipe_lines_read ON public.item_recipe_lines FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());
REVOKE ALL ON public.item_recipes, public.item_recipe_lines
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.item_recipes, public.item_recipe_lines TO authenticated;

CREATE FUNCTION public.app_save_item_recipe_v2(
  p_restaurant_id uuid, p_item_id uuid, p_lines jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_parent public.items%ROWTYPE;
  v_component public.items%ROWTYPE;
  v_line jsonb;
  v_component_id uuid;
  v_unit_id uuid;
  v_quantity numeric;
  v_waste numeric;
  v_order integer;
  v_group text;
  v_base_group text;
  v_count integer := 0;
  v_version integer;
  v_recipe_id uuid;
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);
  -- Serialize updates to one article, preventing duplicate active revisions.
  SELECT * INTO v_parent FROM public.items
  WHERE restaurant_id=p_restaurant_id AND id=p_item_id FOR UPDATE;
  IF NOT FOUND OR NOT v_parent.is_active OR v_parent.item_type='service'
      OR NOT v_parent.uses_recipe THEN
    RAISE EXCEPTION 'recipe_parent_invalid' USING ERRCODE='23514';
  END IF;
  IF p_lines IS NULL OR jsonb_typeof(p_lines)<>'array'
     OR jsonb_array_length(p_lines)=0 THEN
    RAISE EXCEPTION 'recipe_lines_required' USING ERRCODE='22023';
  END IF;

  -- Validate every component before changing the active version.
  FOR v_line IN SELECT value FROM jsonb_array_elements(p_lines) LOOP
    v_component_id := (v_line->>'component_item_id')::uuid;
    v_unit_id := (v_line->>'unit_id')::uuid;
    v_quantity := (v_line->>'quantity')::numeric;
    v_waste := COALESCE((v_line->>'waste_percent')::numeric, 0);
    v_order := COALESCE((v_line->>'display_order')::integer, v_count);
    IF v_component_id=p_item_id OR v_quantity IS NULL OR v_quantity<=0
       OR v_waste<0 OR v_waste>100 OR v_order<0 THEN
      RAISE EXCEPTION 'recipe_line_invalid' USING ERRCODE='23514';
    END IF;
    SELECT * INTO v_component FROM public.items
    WHERE restaurant_id=p_restaurant_id AND id=v_component_id AND is_active;
    IF NOT FOUND OR v_component.item_type='service' THEN
      RAISE EXCEPTION 'recipe_component_invalid' USING ERRCODE='23514';
    END IF;
    SELECT unit_group INTO v_base_group FROM public.measurement_units
    WHERE id=v_component.base_unit_id
      AND (restaurant_id IS NULL OR restaurant_id=p_restaurant_id)
      AND is_active;
    SELECT unit_group INTO v_group FROM public.measurement_units
    WHERE id=v_unit_id AND (restaurant_id IS NULL OR restaurant_id=p_restaurant_id)
      AND is_active;
    IF v_group IS NULL OR v_base_group IS NULL OR v_group<>v_base_group THEN
      RAISE EXCEPTION 'recipe_unit_incompatible' USING ERRCODE='23514';
    END IF;
    -- A component that already depends on the parent would create a cycle.
    IF EXISTS (
      WITH RECURSIVE descendants(item_id, path) AS (
        SELECT v_component_id, ARRAY[v_component_id]
        UNION ALL
        SELECT l.component_item_id, d.path || l.component_item_id
        FROM descendants d
        JOIN public.item_recipes r ON r.restaurant_id=p_restaurant_id
          AND r.item_id=d.item_id AND r.status='active'
        JOIN public.item_recipe_lines l ON l.restaurant_id=r.restaurant_id
          AND l.recipe_id=r.id AND l.is_active
        WHERE NOT l.component_item_id=ANY(d.path)
      )
      SELECT 1 FROM descendants WHERE item_id=p_item_id
    ) THEN
      RAISE EXCEPTION 'recipe_cycle' USING ERRCODE='23514';
    END IF;
    v_count := v_count + 1;
  END LOOP;

  SELECT COALESCE(MAX(version),0)+1 INTO v_version FROM public.item_recipes
  WHERE restaurant_id=p_restaurant_id AND item_id=p_item_id;
  UPDATE public.item_recipes SET status='inactive'
  WHERE restaurant_id=p_restaurant_id AND item_id=p_item_id AND status='active';
  INSERT INTO public.item_recipes(restaurant_id,item_id,version,status)
  VALUES(p_restaurant_id,p_item_id,v_version,'active') RETURNING id INTO v_recipe_id;
  v_count := 0;
  FOR v_line IN SELECT value FROM jsonb_array_elements(p_lines) LOOP
    INSERT INTO public.item_recipe_lines(
      restaurant_id,recipe_id,component_item_id,unit_id,
      quantity,waste_percent,display_order
    ) VALUES (
      p_restaurant_id,v_recipe_id,(v_line->>'component_item_id')::uuid,
      (v_line->>'unit_id')::uuid,(v_line->>'quantity')::numeric,
      COALESCE((v_line->>'waste_percent')::numeric,0),
      COALESCE((v_line->>'display_order')::integer,v_count)
    );
    v_count := v_count+1;
  END LOOP;
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN jsonb_build_object(
    'recipe_id',v_recipe_id,'version',v_version,'line_count',v_count
  );
END;
$$;
REVOKE ALL ON FUNCTION public.app_save_item_recipe_v2(uuid,uuid,jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_save_item_recipe_v2(uuid,uuid,jsonb)
  TO authenticated;
COMMIT;
