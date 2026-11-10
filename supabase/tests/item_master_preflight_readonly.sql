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


-- F0 physical-schema census. Never run this on production.
-- Only object metadata is returned; no credentials, Auth rows or customer data.

-- 1. All public relations, including objects not present in migration text.
SELECT n.nspname AS schema_name, c.relname AS object_name,
       c.relkind AS object_kind, c.relispartition AS partitioned_child,
       c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS force_rls,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS allocated_size,
       COALESCE(s.n_live_tup, 0) AS estimated_live_rows
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
WHERE n.nspname = 'public' AND c.relkind IN ('r','p','v','m')
ORDER BY c.relkind, c.relname;

-- 2. Every FK in public with its exact source/target keys and delete action.
SELECT con.conname AS constraint_name,
       src.relname AS source_table,
       pg_get_constraintdef(con.oid, true) AS exact_foreign_key,
       dst.relname AS target_table,
       con.convalidated AS validated
FROM pg_constraint con
JOIN pg_class src ON src.oid = con.conrelid
JOIN pg_namespace ns ON ns.oid = src.relnamespace
JOIN pg_class dst ON dst.oid = con.confrelid
WHERE ns.nspname = 'public' AND con.contype = 'f'
ORDER BY target_table, source_table, constraint_name;

-- 3. Unique, check and primary-key constraints.
SELECT src.relname AS relation_name, con.conname AS constraint_name,
       con.contype, pg_get_constraintdef(con.oid, true) AS definition
FROM pg_constraint con
JOIN pg_class src ON src.oid = con.conrelid
JOIN pg_namespace ns ON ns.oid = src.relnamespace
WHERE ns.nspname = 'public' AND con.contype IN ('p','u','c','x')
ORDER BY relation_name, con.contype, constraint_name;

-- 4. Columns used by master candidates and their downstream references.
SELECT table_name, ordinal_position, column_name, data_type, udt_name,
       is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
    table_name IN (
      'products','packaging_items','product_categories','measurement_units',
      'product_recipes','product_recipe_lines','product_packaging_rules',
      'sale_items','sales','inventory_stock','inventory_movements',
      'packaging_stock','packaging_movements','inventory_adjustment_lines',
      'employee_raw_material_consumption_lines','modifier_groups',
      'modifier_options','product_modifier_groups','items',
      'item_stock','item_ledger_entries'
    )
    OR column_name IN ('product_id','packaging_item_id','component_product_id',
                       'item_id','restaurant_id')
  )
ORDER BY table_name, ordinal_position;

-- 5. User-visible grants and RLS policy expressions (no credentials).
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual,
       with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

SELECT table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('anon','authenticated','service_role','PUBLIC')
ORDER BY table_name, grantee, privilege_type;

-- 6. Active triggers (also detect active triggers that migration 088 would add).
SELECT rel.relname AS table_name, trg.tgname AS trigger_name,
       pg_get_triggerdef(trg.oid, true) AS trigger_definition,
       trg.tgenabled AS enabled
FROM pg_trigger trg
JOIN pg_class rel ON rel.oid = trg.tgrelid
JOIN pg_namespace ns ON ns.oid = rel.relnamespace
WHERE ns.nspname = 'public' AND NOT trg.tgisinternal
ORDER BY table_name, trigger_name;

-- 7. All functions/RPCs touching item-related tables/fields by BODY,
-- not merely by function name. Hashes help compare actual deployed bodies
-- against versioned migrations without dumping code or JWTs.
SELECT proc.proname AS function_name,
       pg_get_function_identity_arguments(proc.oid) AS arguments,
       proc.prosecdef AS security_definer,
       md5(pg_get_functiondef(proc.oid)) AS function_body_md5,
       pg_get_userbyid(proc.proowner) AS owner
FROM pg_proc proc
JOIN pg_namespace ns ON ns.oid = proc.pronamespace
WHERE ns.nspname = 'public'
  AND (
    pg_get_functiondef(proc.oid) ~* '(products|packaging_items|inventory_stock|packaging_stock|inventory_movements|packaging_movements|product_recipe|product_packaging_rules|product_id|packaging_item_id|item_id)'
    OR proc.proname ~* '^(pos_sync|pos_pull|apply_|app_register|app_save|app_get_)'
  )
ORDER BY function_name, arguments;

-- 8. Deployed migration ledger, including whether 088 was already executed.
SELECT version, name
FROM supabase_migrations.schema_migrations
ORDER BY version;

COMMIT;
