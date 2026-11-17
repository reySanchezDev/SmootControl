-- Remove the retired remote product catalog after all consumers use items.
-- This is intentionally destructive for the local QA database's legacy data.
BEGIN;

DROP TABLE IF EXISTS public.product_recipe_lines CASCADE;
DROP TABLE IF EXISTS public.product_recipes CASCADE;
DROP TABLE IF EXISTS public.product_modifier_groups CASCADE;
DROP TABLE IF EXISTS public.product_packaging_rules CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP FUNCTION IF EXISTS public.validate_product_packaging_rule_tenant();

COMMIT;
