CREATE TABLE IF NOT EXISTS public.product_recipes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  effective_from timestamptz NOT NULL DEFAULT now(),
  created_by_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, product_id, version)
);

CREATE UNIQUE INDEX IF NOT EXISTS product_recipes_one_active_uidx
  ON public.product_recipes (restaurant_id, product_id)
  WHERE status = 'active';

CREATE TABLE IF NOT EXISTS public.product_recipe_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  recipe_id uuid NOT NULL REFERENCES public.product_recipes(id) ON DELETE CASCADE,
  component_product_id uuid NOT NULL REFERENCES public.products(id),
  quantity numeric(18, 6) NOT NULL CHECK (quantity > 0),
  unit_id uuid NOT NULL REFERENCES public.measurement_units(id),
  waste_percent numeric(8, 4) NOT NULL DEFAULT 0 CHECK (waste_percent >= 0),
  display_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS product_recipe_lines_recipe_idx
  ON public.product_recipe_lines (recipe_id, display_order);

ALTER TABLE public.product_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_recipe_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS product_recipes_same_restaurant
  ON public.product_recipes;
CREATE POLICY product_recipes_same_restaurant
  ON public.product_recipes
  FOR ALL
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS product_recipe_lines_same_restaurant
  ON public.product_recipe_lines;
CREATE POLICY product_recipe_lines_same_restaurant
  ON public.product_recipe_lines
  FOR ALL
  USING (public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

CREATE OR REPLACE FUNCTION public.app_recipe_component_expands_to(
  p_restaurant_id uuid,
  p_start_product_id uuid,
  p_target_product_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH RECURSIVE recipe_tree(component_product_id, depth, path) AS (
    SELECT
      line.component_product_id,
      1,
      ARRAY[line.component_product_id]
    FROM public.product_recipes recipe
    JOIN public.product_recipe_lines line
      ON line.recipe_id = recipe.id
     AND line.restaurant_id = recipe.restaurant_id
     AND line.is_active = true
    WHERE recipe.restaurant_id = p_restaurant_id
      AND recipe.product_id = p_start_product_id
      AND recipe.status = 'active'

    UNION ALL

    SELECT
      next_line.component_product_id,
      recipe_tree.depth + 1,
      recipe_tree.path || next_line.component_product_id
    FROM recipe_tree
    JOIN public.product_recipes next_recipe
      ON next_recipe.restaurant_id = p_restaurant_id
     AND next_recipe.product_id = recipe_tree.component_product_id
     AND next_recipe.status = 'active'
    JOIN public.product_recipe_lines next_line
      ON next_line.recipe_id = next_recipe.id
     AND next_line.restaurant_id = next_recipe.restaurant_id
     AND next_line.is_active = true
    WHERE recipe_tree.depth < 20
      AND NOT next_line.component_product_id = ANY(recipe_tree.path)
  )
  SELECT EXISTS (
    SELECT 1
    FROM recipe_tree
    WHERE component_product_id = p_target_product_id
  );
$$;

CREATE OR REPLACE FUNCTION public.app_save_product_recipe(
  p_restaurant_id uuid,
  p_product_id uuid,
  p_lines jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_product public.products%ROWTYPE;
  component_product public.products%ROWTYPE;
  line_payload jsonb;
  line_count integer := 0;
  next_version integer := 1;
  recipe_id uuid;
  line_unit_id uuid;
  line_quantity numeric;
  line_waste numeric;
  line_order integer;
  component_unit_group text;
  recipe_unit_group text;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'productos.gestionar'
  );

  SELECT *
    INTO target_product
    FROM public.products
   WHERE id = p_product_id
     AND restaurant_id = p_restaurant_id
     AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto de receta no existe o esta inactivo'
      USING ERRCODE = '23503';
  END IF;

  IF target_product.product_kind = 'raw_material' THEN
    RAISE EXCEPTION 'Una materia prima no puede tener receta'
      USING ERRCODE = '23514';
  END IF;

  IF jsonb_typeof(COALESCE(p_lines, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'Lineas de receta invalidas'
      USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(MAX(version), 0) + 1
    INTO next_version
    FROM public.product_recipes
   WHERE restaurant_id = p_restaurant_id
     AND product_id = p_product_id;

  UPDATE public.product_recipes
     SET status = 'inactive',
         updated_at = now()
   WHERE restaurant_id = p_restaurant_id
     AND product_id = p_product_id
     AND status = 'active';

  INSERT INTO public.product_recipes (
    restaurant_id,
    product_id,
    version,
    status,
    effective_from,
    created_by_user_id
  )
  VALUES (
    p_restaurant_id,
    p_product_id,
    next_version,
    'active',
    now(),
    auth.uid()
  )
  RETURNING id INTO recipe_id;

  FOR line_payload IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_lines, '[]'::jsonb))
  LOOP
    SELECT *
      INTO component_product
      FROM public.products
     WHERE id = (line_payload ->> 'component_product_id')::uuid
       AND restaurant_id = p_restaurant_id
       AND is_active = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Componente de receta no existe o esta inactivo'
        USING ERRCODE = '23503';
    END IF;

    IF component_product.id = p_product_id THEN
      RAISE EXCEPTION 'La receta no puede consumirse a si misma'
        USING ERRCODE = '23514';
    END IF;

    IF component_product.product_kind = 'finished'
       AND component_product.uses_recipe = false THEN
      RAISE EXCEPTION 'Componente no valido para receta: %',
        component_product.name
        USING ERRCODE = '23514';
    END IF;

    IF component_product.inventory_unit_id IS NULL THEN
      RAISE EXCEPTION 'Componente sin unidad base: %',
        component_product.name
        USING ERRCODE = '23514';
    END IF;

    IF public.app_recipe_component_expands_to(
      p_restaurant_id,
      component_product.id,
      p_product_id
    ) THEN
      RAISE EXCEPTION 'La receta genera un ciclo con %',
        component_product.name
        USING ERRCODE = '23514';
    END IF;

    line_unit_id := (line_payload ->> 'unit_id')::uuid;
    line_quantity := (line_payload ->> 'quantity')::numeric;
    line_waste := COALESCE((line_payload ->> 'waste_percent')::numeric, 0);
    line_order := COALESCE((line_payload ->> 'display_order')::integer, line_count);

    IF line_quantity IS NULL OR line_quantity <= 0 THEN
      RAISE EXCEPTION 'Cantidad de receta invalida'
        USING ERRCODE = '23514';
    END IF;

    SELECT unit_group
      INTO component_unit_group
      FROM public.measurement_units
     WHERE id = component_product.inventory_unit_id
       AND (restaurant_id IS NULL OR restaurant_id = p_restaurant_id)
       AND is_active = true;

    SELECT unit_group
      INTO recipe_unit_group
      FROM public.measurement_units
     WHERE id = line_unit_id
       AND (restaurant_id IS NULL OR restaurant_id = p_restaurant_id)
       AND is_active = true;

    IF component_unit_group IS NULL OR recipe_unit_group IS NULL THEN
      RAISE EXCEPTION 'Unidad de receta invalida'
        USING ERRCODE = '23514';
    END IF;

    IF component_unit_group <> recipe_unit_group THEN
      RAISE EXCEPTION 'Unidad incompatible para componente %',
        component_product.name
        USING ERRCODE = '23514';
    END IF;

    INSERT INTO public.product_recipe_lines (
      restaurant_id,
      recipe_id,
      component_product_id,
      quantity,
      unit_id,
      waste_percent,
      display_order,
      is_active
    )
    VALUES (
      p_restaurant_id,
      recipe_id,
      component_product.id,
      line_quantity,
      line_unit_id,
      line_waste,
      line_order,
      true
    );

    line_count := line_count + 1;
  END LOOP;

  IF line_count = 0 THEN
    RAISE EXCEPTION 'La receta debe tener al menos un componente'
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.products
     SET uses_recipe = true,
         updated_at = now()
   WHERE id = p_product_id
     AND restaurant_id = p_restaurant_id;

  RETURN jsonb_build_object(
    'recipe_id', recipe_id,
    'version', next_version,
    'line_count', line_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.app_recipe_component_expands_to(uuid, uuid, uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_save_product_recipe(uuid, uuid, jsonb)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_save_product_recipe(uuid, uuid, jsonb)
  TO authenticated;
