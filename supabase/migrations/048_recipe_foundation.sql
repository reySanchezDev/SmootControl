-- Base no destructiva para recetas, unidades y regla de inventario negativo.

CREATE TABLE IF NOT EXISTS public.measurement_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid REFERENCES public.restaurants(id) ON DELETE CASCADE,
  code text NOT NULL,
  name text NOT NULL,
  unit_group text NOT NULL
    CHECK (unit_group IN ('count', 'mass', 'volume')),
  base_factor numeric(18, 6) NOT NULL DEFAULT 1
    CHECK (base_factor > 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS measurement_units_global_code_uidx
  ON public.measurement_units (code)
  WHERE restaurant_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS measurement_units_restaurant_code_uidx
  ON public.measurement_units (restaurant_id, code)
  WHERE restaurant_id IS NOT NULL;

ALTER TABLE public.measurement_units ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS measurement_units_same_restaurant
  ON public.measurement_units;
CREATE POLICY measurement_units_same_restaurant
  ON public.measurement_units
  FOR ALL TO authenticated
  USING (restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id))
  WITH CHECK (restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id));

INSERT INTO public.measurement_units (restaurant_id, code, name, unit_group, base_factor)
VALUES
  (NULL, 'unit', 'Unidad', 'count', 1),
  (NULL, 'g', 'Gramo', 'mass', 1),
  (NULL, 'kg', 'Kilogramo', 'mass', 1000),
  (NULL, 'oz', 'Onza', 'mass', 28.3495),
  (NULL, 'ml', 'Mililitro', 'volume', 1),
  (NULL, 'l', 'Litro', 'volume', 1000)
ON CONFLICT DO NOTHING;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS product_kind text NOT NULL DEFAULT 'finished',
  ADD COLUMN IF NOT EXISTS uses_recipe boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS purchase_unit_id uuid
    REFERENCES public.measurement_units(id),
  ADD COLUMN IF NOT EXISTS inventory_unit_id uuid
    REFERENCES public.measurement_units(id),
  ADD COLUMN IF NOT EXISTS purchase_to_inventory_factor numeric(18, 6);

UPDATE public.products
   SET product_kind = CASE
     WHEN is_raw_material THEN 'raw_material'
     ELSE 'finished'
   END
 WHERE product_kind IS NULL OR product_kind = 'finished';

UPDATE public.products
   SET uses_recipe = false
 WHERE product_kind = 'raw_material'
   AND uses_recipe = true;

ALTER TABLE public.products
  DROP CONSTRAINT IF EXISTS products_product_kind_chk;
ALTER TABLE public.products
  ADD CONSTRAINT products_product_kind_chk
  CHECK (product_kind IN ('finished', 'raw_material', 'preparation'));

ALTER TABLE public.products
  DROP CONSTRAINT IF EXISTS products_raw_material_without_recipe_chk;
ALTER TABLE public.products
  ADD CONSTRAINT products_raw_material_without_recipe_chk
  CHECK (product_kind <> 'raw_material' OR uses_recipe = false);

ALTER TABLE public.products
  DROP CONSTRAINT IF EXISTS products_price_sellable_or_raw_material_chk;
ALTER TABLE public.products
  ADD CONSTRAINT products_price_sellable_or_raw_material_chk
  CHECK (
    (product_kind = 'raw_material' AND price >= 0)
    OR
    (product_kind <> 'raw_material' AND price > 0)
  );

COMMENT ON COLUMN public.products.product_kind IS
  'finished vendible, raw_material materia prima, preparation receta intermedia.';
COMMENT ON COLUMN public.products.uses_recipe IS
  'True when selling or consuming this product explodes recipe components.';
COMMENT ON COLUMN public.products.inventory_unit_id IS
  'Base inventory unit used for stock and recipe consumption conversions.';
COMMENT ON COLUMN public.products.purchase_unit_id IS
  'Usual purchase unit for inventory entry screens.';
COMMENT ON COLUMN public.products.purchase_to_inventory_factor IS
  'Conversion factor from purchase unit to inventory base unit.';

INSERT INTO public.business_rules (restaurant_id, key, bool_value)
SELECT id, 'allow_raw_material_negative_stock_from_recipes', true
  FROM public.restaurants
ON CONFLICT (restaurant_id, key) DO NOTHING;
