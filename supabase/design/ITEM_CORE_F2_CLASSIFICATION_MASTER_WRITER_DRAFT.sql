-- KIVO F2.3 — ITEM CLASSIFICATION MASTER WRITE CONTRACT (DESIGN ONLY)
-- Do not apply as migration or execute in operating databases.
-- Must be deployed only together with classification link writers and pull DTO.
CREATE OR REPLACE FUNCTION public.app_upsert_item_classification_v2(
  p_restaurant_id uuid,
  p_classification_id uuid,
  p_code text,
  p_name text,
  p_is_active boolean
) RETURNS public.item_classifications
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp
SET row_security=off
AS $$
DECLARE
  v_revision bigint;
  v_previous public.item_classifications;
  v_result public.item_classifications;
  v_code text;
  v_name text;
BEGIN
  IF p_restaurant_id IS NULL OR p_classification_id IS NULL
     OR NOT public.app_item_has_write_access(
       p_restaurant_id,'articulos.gestionar'
     ) THEN
    RAISE EXCEPTION 'item_classification_write_not_authorized'
      USING ERRCODE='42501';
  END IF;
  v_code:=btrim(p_code);
  v_name:=btrim(p_name);
  IF v_code IS NULL OR length(v_code) NOT BETWEEN 1 AND 64
     OR v_name IS NULL OR length(v_name) NOT BETWEEN 1 AND 250
     OR p_is_active IS NULL THEN
    RAISE EXCEPTION 'invalid_item_classification_fields'
      USING ERRCODE='22023';
  END IF;

  -- One global per-tenant catalog lock, acquired BEFORE any master DML.
  SELECT revision INTO v_revision
  FROM public.item_catalog_revisions
  WHERE restaurant_id=p_restaurant_id FOR UPDATE;
  IF v_revision IS NULL THEN
    RAISE EXCEPTION 'item_catalog_revision_not_initialized'
      USING ERRCODE='23503';
  END IF;
  SELECT * INTO v_previous
  FROM public.item_classifications
  WHERE restaurant_id=p_restaurant_id AND id=p_classification_id
  FOR UPDATE;
  IF v_previous.id IS NULL AND EXISTS(
    SELECT 1 FROM public.item_classifications
    WHERE id=p_classification_id
  ) THEN
    RAISE EXCEPTION 'classification_cross_tenant_id_collision'
      USING ERRCODE='23505';
  END IF;
  IF v_previous.id IS NOT NULL
     AND v_previous.code=v_code
     AND v_previous.name=v_name
     AND v_previous.is_active=p_is_active THEN
    RETURN v_previous;
  END IF;
  -- Reject ambiguous names/codes within the same tenant, regardless of case.
  IF EXISTS(
    SELECT 1 FROM public.item_classifications c
    WHERE c.restaurant_id=p_restaurant_id
      AND c.id<>p_classification_id
      AND lower(btrim(c.code))=lower(v_code)
  ) THEN
    RAISE EXCEPTION 'duplicate_item_classification_code'
      USING ERRCODE='23505';
  END IF;
  -- Never disable a classification that remains assigned to an item.
  IF NOT p_is_active AND EXISTS(
    SELECT 1 FROM public.item_classification_links l
    WHERE l.restaurant_id=p_restaurant_id
      AND l.classification_id=p_classification_id
  ) THEN
    RAISE EXCEPTION 'classification_still_assigned'
      USING ERRCODE='23514';
  END IF;

  INSERT INTO public.item_classifications(
    id,restaurant_id,code,name,is_active
  ) VALUES(
    p_classification_id,p_restaurant_id,v_code,v_name,p_is_active
  ) ON CONFLICT(id) DO UPDATE SET
    code=EXCLUDED.code,
    name=EXCLUDED.name,
    is_active=EXCLUDED.is_active
  RETURNING * INTO v_result;
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_result;
END;
$$;

REVOKE ALL ON public.item_classifications FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.item_classifications TO authenticated;
REVOKE ALL ON FUNCTION public.app_upsert_item_classification_v2(
  uuid,uuid,text,text,boolean
) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_classification_v2(
  uuid,uuid,text,text,boolean
) TO authenticated;

-- G2: classification master/links must join complete POS pull+Drift atomically;
-- JWT/RLS, unknown old writers and lifecycle must be verified before cutover.
