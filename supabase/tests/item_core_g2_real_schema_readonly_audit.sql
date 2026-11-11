-- G2 authorized lab: READ-ONLY catalog inventory, NOT security approval.
-- No CREATE/ALTER/DELETE/INSERT, no JWT token values, no customer rows.
-- Use ONLY with explicitly approved Supabase lab connection.
BEGIN TRANSACTION READ ONLY;
SET LOCAL statement_timeout = '10s';
SET LOCAL lock_timeout = '2s';

SELECT current_database() AS database_name,
       current_user AS inspecting_role,
       current_schema() AS active_schema,
       current_setting('server_version') AS postgres_version;

WITH expected(relname) AS (
  VALUES ('items'), ('item_units'), ('item_classifications'),
         ('item_classification_links'), ('item_consumption_rules'),
         ('item_catalog_revisions')
)
SELECT e.relname AS expected_table,
       n.nspname AS detected_schema,
       c.relkind AS object_type,
       c.relrowsecurity AS row_level_security_enabled,
       c.relforcerowsecurity AS force_row_level_security,
       (SELECT count(*) FROM pg_policies p
        WHERE p.schemaname = n.nspname AND p.tablename = c.relname
       ) AS policy_count,
       CASE WHEN c.oid IS NOT NULL
          AND EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated')
         THEN has_table_privilege(
           'authenticated'::name, c.oid, 'INSERT, UPDATE, DELETE')
       END AS authenticated_can_write_directly
FROM expected e
LEFT JOIN pg_class c ON c.relname=e.relname
  AND c.relnamespace='public'::regnamespace
LEFT JOIN pg_namespace n ON n.oid=c.relnamespace
ORDER BY e.relname;

WITH expected(proname) AS (
  VALUES ('app_upsert_item_v2'), ('app_upsert_item_unit_v2'),
         ('app_upsert_item_classification_v2'),
         ('app_set_item_classification_v2'),
         ('app_upsert_item_consumption_rule_v2'),
         ('pos_pull_item_catalog_v2')
)
SELECT e.proname AS expected_rpc,
       p.oid::regprocedure::text AS actual_signature,
       p.prosecdef AS security_definer,
       p.proconfig AS secure_search_path,
       CASE WHEN p.oid IS NOT NULL
          AND EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated')
         THEN has_function_privilege('authenticated'::name, p.oid, 'EXECUTE')
       END AS authenticated_can_execute
FROM expected e
LEFT JOIN pg_proc p ON p.proname=e.proname
  AND p.pronamespace='public'::regnamespace
ORDER BY e.proname, actual_signature;

-- Inspect policies, never equate policy existence with JWT authorization.
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual,
       with_check
FROM pg_policies
WHERE schemaname='public'
  AND tablename IN (
    'items','item_units','item_classifications',
    'item_classification_links','item_consumption_rules',
    'item_catalog_revisions'
  )
ORDER BY tablename, policyname;

ROLLBACK;
