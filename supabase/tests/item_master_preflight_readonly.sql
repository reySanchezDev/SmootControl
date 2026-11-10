-- READ-ONLY local preflight. Must run before migration 088.
-- No updates, deletes, DDL, DB reset or service credentials.
BEGIN READ ONLY;

SELECT 'products' AS entity, count(*) AS count
FROM public.products
UNION ALL SELECT 'packaging_items', count(*) FROM public.packaging_items
UNION ALL SELECT 'inventory_stock', count(*) FROM public.inventory_stock
UNION ALL SELECT 'inventory_movements', count(*) FROM public.inventory_movements
UNION ALL SELECT 'packaging_stock', count(*) FROM public.packaging_stock
UNION ALL SELECT 'packaging_movements', count(*) FROM public.packaging_movements
UNION ALL SELECT 'product_packaging_rules', count(*)
FROM public.product_packaging_rules;

-- Each count MUST be zero before applying the migration.
SELECT 'product-packaging UUID collision' AS issue, count(*) AS blockers
FROM public.products p JOIN public.packaging_items k ON k.id = p.id
UNION ALL
SELECT 'case-insensitive product codes', count(*) FROM (
  SELECT restaurant_id, lower(btrim(code))
  FROM public.products GROUP BY restaurant_id, lower(btrim(code))
  HAVING count(*) > 1
) q
UNION ALL
SELECT 'product code vs reserved packaging code', count(*)
FROM public.products p
JOIN public.packaging_items k
  ON k.restaurant_id = p.restaurant_id
 AND lower(btrim(p.code)) = lower('PKG-' || k.id::text)
UNION ALL
SELECT 'invalid or blank product codes', count(*)
FROM public.products
WHERE length(btrim(code)) = 0
UNION ALL
SELECT 'cross-tenant product category', count(*)
FROM public.products p JOIN public.product_categories c ON c.id = p.category_id
WHERE p.restaurant_id <> c.restaurant_id
UNION ALL
SELECT 'cross-tenant packaging rule references', count(*)
FROM public.product_packaging_rules r
JOIN public.products p ON p.id = r.product_id
JOIN public.packaging_items k ON k.id = r.packaging_item_id
JOIN public.sales_types s ON s.id = r.sales_type_id
WHERE p.restaurant_id <> r.restaurant_id
   OR k.restaurant_id <> r.restaurant_id
   OR s.restaurant_id <> r.restaurant_id
UNION ALL
SELECT 'product stock tenant mismatch', count(*)
FROM public.inventory_stock s
JOIN public.products p ON p.id = s.product_id
WHERE s.restaurant_id <> p.restaurant_id
UNION ALL
SELECT 'packaging stock tenant mismatch', count(*)
FROM public.packaging_stock s
JOIN public.packaging_items k ON k.id = s.packaging_item_id
WHERE s.restaurant_id <> k.restaurant_id;

-- Structural inventory + sales referential evidence (non-destructive).
SELECT table_name, column_name, foreign_table_name
FROM (
  SELECT tc.table_name, kcu.column_name,
         ccu.table_name AS foreign_table_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
   AND tc.constraint_schema = kcu.constraint_schema
  JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
   AND ccu.constraint_schema = tc.constraint_schema
  WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
) f
WHERE foreign_table_name IN ('products', 'packaging_items')
ORDER BY foreign_table_name, table_name, column_name;

COMMIT;
