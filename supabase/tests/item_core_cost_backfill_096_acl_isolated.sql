-- Safe ACL regression for migration 096. Uses a disposable PostgreSQL instance.
-- Never execute app_backfill_missing_sale_costs under anon/authenticated:
-- a local PostgreSQL SIGSEGV is under separate investigation.
BEGIN;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE FUNCTION public.app_backfill_missing_sale_costs(uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$ BEGIN RETURN '{}'::jsonb; END; $$;
GRANT EXECUTE ON FUNCTION public.app_backfill_missing_sale_costs(uuid)
TO PUBLIC, anon, authenticated;
COMMIT;
\ir ../migrations/096_harden_sale_cost_backfill_execute.sql

DO $$
DECLARE
  actual_path text;
BEGIN
  IF has_function_privilege('anon',
      'public.app_backfill_missing_sale_costs(uuid)', 'EXECUTE')
    OR has_function_privilege('authenticated',
      'public.app_backfill_missing_sale_costs(uuid)', 'EXECUTE')
    OR NOT has_function_privilege('service_role',
      'public.app_backfill_missing_sale_costs(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Backfill 096 execute ACL is incorrect';
  END IF;
  SELECT p.proconfig[1] INTO actual_path
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='app_backfill_missing_sale_costs'
    AND p.pronargs=1;
  IF actual_path IS DISTINCT FROM 'search_path=public, pg_temp' THEN
    RAISE EXCEPTION 'Backfill 096 search_path mismatch: %',actual_path;
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    JOIN pg_roles owner ON owner.oid=p.proowner
    WHERE n.nspname='public' AND p.proname='app_backfill_missing_sale_costs'
      AND p.pronargs=1 AND NOT p.prosecdef
  ) THEN RAISE EXCEPTION 'Security definer flag missing'; END IF;
END;
$$;
