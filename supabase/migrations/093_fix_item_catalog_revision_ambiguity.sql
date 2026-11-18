-- Corrective migration for the already-installed 089 revision helper.
BEGIN;

CREATE OR REPLACE FUNCTION item_core_internal.bump_item_catalog_revision(
  p_restaurant_id uuid
) RETURNS TABLE (revision bigint, snapshot_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE public.item_catalog_revisions
  SET revision = public.item_catalog_revisions.revision + 1,
      snapshot_id = gen_random_uuid(),
      updated_at = now()
  WHERE item_catalog_revisions.restaurant_id = p_restaurant_id
  RETURNING item_catalog_revisions.revision, item_catalog_revisions.snapshot_id
  INTO revision, snapshot_id;
  IF revision IS NULL THEN
    INSERT INTO public.item_catalog_revisions(restaurant_id)
    VALUES (p_restaurant_id)
    RETURNING item_catalog_revisions.revision, item_catalog_revisions.snapshot_id
    INTO revision, snapshot_id;
  END IF;
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION item_core_internal.bump_item_catalog_revision(uuid)
  FROM PUBLIC, anon, authenticated;

COMMIT;
