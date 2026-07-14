-- Allow raw materials to have zero sale price while keeping sellable products priced.
DO $$
DECLARE
  constraint_record record;
BEGIN
  FOR constraint_record IN
    SELECT constraint_name
      FROM information_schema.check_constraints
     WHERE constraint_schema = 'public'
       AND check_clause LIKE '%price%'
       AND check_clause LIKE '%> 0%'
  LOOP
    IF EXISTS (
      SELECT 1
        FROM information_schema.constraint_table_usage usage
       WHERE usage.constraint_schema = 'public'
         AND usage.constraint_name = constraint_record.constraint_name
         AND usage.table_schema = 'public'
         AND usage.table_name = 'products'
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.products DROP CONSTRAINT IF EXISTS %I',
        constraint_record.constraint_name
      );
    END IF;
  END LOOP;
END $$;

ALTER TABLE public.products
  ADD CONSTRAINT products_price_sellable_or_raw_material_chk
  CHECK (
    (is_raw_material = true AND price >= 0)
    OR
    (is_raw_material = false AND price > 0)
  );
