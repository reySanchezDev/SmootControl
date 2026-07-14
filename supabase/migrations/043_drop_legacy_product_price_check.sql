-- Remove the legacy positive-price check now that raw materials can have zero price.
ALTER TABLE public.products
  DROP CONSTRAINT IF EXISTS products_price_check;

ALTER TABLE public.products
  DROP CONSTRAINT IF EXISTS products_price_sellable_or_raw_material_chk;

ALTER TABLE public.products
  ADD CONSTRAINT products_price_sellable_or_raw_material_chk
  CHECK (
    (is_raw_material = true AND price >= 0)
    OR
    (is_raw_material = false AND price > 0)
  );
