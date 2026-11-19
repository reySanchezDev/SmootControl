-- This helper only serves the SECURITY DEFINER sale-sync RPC. Direct callers
-- must not be able to probe packaging UUIDs across restaurant boundaries.
BEGIN;

REVOKE ALL ON FUNCTION public.filter_legacy_packaging_movements(uuid, jsonb)
  FROM PUBLIC, anon, authenticated;

COMMIT;
