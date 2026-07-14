-- Product catalog flag used to separate sellable items from raw material.
-- Existing products remain sellable by default to preserve current POS behavior.

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS is_raw_material boolean NOT NULL DEFAULT false;

UPDATE public.products
   SET is_raw_material = false
 WHERE is_raw_material IS NULL;

UPDATE public.products
   SET is_available_in_pos = false,
       updated_at = now()
 WHERE is_raw_material = true;

COMMENT ON COLUMN public.products.is_raw_material IS
  'True when the product is inventory raw material and not sold directly in POS.';
