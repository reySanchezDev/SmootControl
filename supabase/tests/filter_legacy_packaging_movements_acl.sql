-- Checks the helper is private while its trusted sale-sync owner can call it.
BEGIN;

DO $test$
DECLARE
  helper regprocedure :=
    'public.filter_legacy_packaging_movements(uuid,jsonb)'::regprocedure;
  sale_sync_owner name;
BEGIN
  SELECT pg_get_userbyid(proowner) INTO sale_sync_owner
  FROM pg_proc
  WHERE oid = 'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure;

  IF EXISTS (
       SELECT 1
       FROM pg_proc function
       CROSS JOIN LATERAL aclexplode(
         COALESCE(function.proacl, acldefault('f', function.proowner))
       ) privilege
       WHERE function.oid = helper
         AND privilege.grantee = 0
         AND privilege.privilege_type = 'EXECUTE'
     )
     OR has_function_privilege('anon', helper, 'EXECUTE')
     OR has_function_privilege('authenticated', helper, 'EXECUTE') THEN
    RAISE EXCEPTION 'legacy_packaging_filter_must_be_private';
  END IF;
  IF NOT has_function_privilege(sale_sync_owner, helper, 'EXECUTE') THEN
    RAISE EXCEPTION 'sale_sync_owner_cannot_call_legacy_packaging_filter';
  END IF;
  IF NOT has_function_privilege('service_role', helper, 'EXECUTE') THEN
    RAISE EXCEPTION 'service_role_legacy_packaging_access_changed';
  END IF;
END;
$test$;

ROLLBACK;
