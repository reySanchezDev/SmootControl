-- KIVO F2.3 - ITEM CLASSIFICATION LINK WRITER (DESIGN ONLY)
-- NOT A MIGRATION. Do not execute against operating databases.
-- This writer must replace all direct item_classification_links mutations.
CREATE OR REPLACE FUNCTION public.app_set_item_classification_v2(
  p_restaurant_id uuid,
  p_item_id uuid,
  p_classification_id uuid,
  p_enabled boolean
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp
SET row_security=off
AS $$
DECLARE
  v_revision bigint;
  v_exists boolean;
BEGIN
  IF p_restaurant_id IS NULL OR p_item_id IS NULL
     OR p_classification_id IS NULL OR p_enabled IS NULL
     OR NOT public.app_item_has_write_access(
       p_restaurant_id,'articulos.gestionar'
     ) THEN
    RAISE EXCEPTION 'item_classification_not_authorized'
      USING ERRCODE='42501';
  END IF;
  -- Serialize changes and POS snapshot publication before any DML.
  SELECT revision INTO v_revision FROM public.item_catalog_revisions
  WHERE restaurant_id=p_restaurant_id FOR UPDATE;
  IF v_revision IS NULL THEN
    RAISE EXCEPTION 'item_catalog_revision_not_initialized'
      USING ERRCODE='23503';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.items
    WHERE restaurant_id=p_restaurant_id AND id=p_item_id
  ) THEN
    RAISE EXCEPTION 'item_classification_item_missing'
      USING ERRCODE='23503';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.item_classifications
    WHERE restaurant_id=p_restaurant_id AND id=p_classification_id
      AND is_active
  ) THEN
    RAISE EXCEPTION 'item_classification_invalid_target'
      USING ERRCODE='23514';
  END IF;
  SELECT EXISTS(
    SELECT 1 FROM public.item_classification_links
    WHERE restaurant_id=p_restaurant_id AND item_id=p_item_id
      AND classification_id=p_classification_id
  ) INTO v_exists;
  IF v_exists=p_enabled THEN
    RETURN false; -- exact replay: do not change revision
  END IF;
  IF p_enabled THEN
    INSERT INTO public.item_classification_links(
      restaurant_id,item_id,classification_id
    ) VALUES(p_restaurant_id,p_item_id,p_classification_id);
  ELSE
    DELETE FROM public.item_classification_links
    WHERE restaurant_id=p_restaurant_id AND item_id=p_item_id
      AND classification_id=p_classification_id;
  END IF;
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN true;
END;
$$;

REVOKE ALL ON public.item_classification_links
  FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.item_classification_links TO authenticated;
REVOKE ALL ON FUNCTION public.app_set_item_classification_v2(
  uuid,uuid,uuid,boolean
) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_set_item_classification_v2(
  uuid,uuid,uuid,boolean
) TO authenticated;

-- G2 blocker: catalog pull must expose classifications/links, real JWT/RLS
-- and remaining classification master CRUD need independent verification.
