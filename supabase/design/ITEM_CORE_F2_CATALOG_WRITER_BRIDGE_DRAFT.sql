-- KIVO F2.3 - TEMPORARY CANONICAL ITEM WRITER BRIDGE (DESIGN ONLY)
-- DO NOT EXECUTE against operating environments or move to migrations.
-- Prerequisites: F1 authoritative app_upsert_item (security hardened);
-- F2 item_catalog_revisions, private bump helper and item master tables.
-- This is a coordinated CUTOVER contract, never enabled independently.
--
-- All client write access to the previous app_upsert_item is removed.
-- The new RPC validates actor rights, locks catalog revision BEFORE
-- changing items or units/classification links, invokes the F1 writer
-- and advances the snapshot once within the SAME database transaction.
-- If any operation fails, the lock, mutation and bump all roll back.
CREATE OR REPLACE FUNCTION public.app_upsert_item_v2(
  p_restaurant_id uuid,
  p_payload jsonb
) RETURNS public.items LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp
SET row_security=off
AS $$
DECLARE
  v_previous_revision bigint;
  v_item public.items;
BEGIN
  IF p_restaurant_id IS NULL
    OR NOT public.app_item_has_write_access(
      p_restaurant_id,'articulos.gestionar'
    ) THEN
    RAISE EXCEPTION 'item_write_not_authorized' USING ERRCODE='42501';
  END IF;
  IF p_payload IS NULL OR jsonb_typeof(p_payload)<>'object' THEN
    RAISE EXCEPTION 'invalid_item_payload' USING ERRCODE='22023';
  END IF;

  -- Lock before ANY catalog write. Every rule/unit/category writer must
  -- follow the identical lock ordering to maintain revision integrity.
  SELECT revision INTO v_previous_revision
  FROM public.item_catalog_revisions
  WHERE restaurant_id=p_restaurant_id
  FOR UPDATE;
  IF v_previous_revision IS NULL THEN
    RAISE EXCEPTION 'item_catalog_revision_not_initialized'
      USING ERRCODE='23503';
  END IF;

  v_item:=public.app_upsert_item(p_restaurant_id,p_payload);
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_item;
END;
$$;

-- The new bridge MUST become the only client master-write entry point
-- during the synchronized F1/F2 cutover. No direct old RPC execute.
REVOKE ALL ON FUNCTION public.app_upsert_item(uuid,jsonb)
  FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.app_upsert_item_v2(uuid,jsonb)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_v2(uuid,jsonb)
  TO authenticated;

-- Deferred gate G2:
-- - Rewire all upsert clients to v2, not just the main products form.
-- - Guard item_units/classifications/rules/categories mutations with
--   revision lock+increment and deny old direct grants on those tables.
-- - Confirm permission/RLS and cross-tenant with signed JWT in actual DB.
-- - Prevent any POS/backend paths writing catalog without the same lock.
-- - After full replacement, merge logic into one canonical RPC: the
--   bridge is NOT intended to be a permanent duplicate write API.
