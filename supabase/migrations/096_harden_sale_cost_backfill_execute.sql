-- Harden the maintenance-only backfill introduced by 095.
-- Never rewrite an applied migration: client roles must not execute this
-- SECURITY DEFINER routine with an arbitrary restaurant argument.
BEGIN;

ALTER FUNCTION public.app_backfill_missing_sale_costs(uuid)
  SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.app_backfill_missing_sale_costs(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_backfill_missing_sale_costs(uuid)
  TO service_role;

COMMIT;
