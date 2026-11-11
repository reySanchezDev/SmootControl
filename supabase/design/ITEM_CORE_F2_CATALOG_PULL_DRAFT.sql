-- KIVO F2.3 / CANONICAL POS CATALOG SNAPSHOT (DESIGN ONLY)
-- NOT A MIGRATION. Never run against an operating tenant.
-- Contract: the entire tenant catalog, not POS-filtered rows/pagination.
-- Requires exact coordination with the master/rule/unit write RPCs.
-- Every trusted catalog write MUST lock item_catalog_revisions FOR UPDATE
-- BEFORE changing any item, unit, classification or consumption rule, then
-- increment revision and replace snapshot_id INSIDE THE SAME TRANSACTION.
-- Without this writer protocol, revision and snapshot cannot be trusted.
--
-- Catalog sync does not change the existing POS/Drift v34 workflow.
CREATE TABLE public.item_catalog_revisions (
  restaurant_id uuid PRIMARY KEY REFERENCES public.restaurants(id),
  revision bigint NOT NULL DEFAULT 1 CHECK(revision > 0),
  snapshot_id uuid NOT NULL DEFAULT gen_random_uuid(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.item_catalog_revisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.item_catalog_revisions FROM PUBLIC, anon, authenticated;

-- This internal writer helper must be called AFTER taking a revision row
-- FOR UPDATE and BEFORE committing a catalog change. Caller owns the lock.
-- Not exposed through PostgREST. Its production owner/grants require review.
CREATE OR REPLACE FUNCTION item_core_internal.bump_item_catalog_revision(
  p_restaurant_id uuid
) RETURNS bigint LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_revision bigint;
BEGIN
  INSERT INTO public.item_catalog_revisions(restaurant_id)
  VALUES(p_restaurant_id)
  ON CONFLICT(restaurant_id) DO NOTHING;

  UPDATE public.item_catalog_revisions
  SET revision=revision+1,snapshot_id=gen_random_uuid(),updated_at=now()
  WHERE restaurant_id=p_restaurant_id
  RETURNING revision INTO v_revision;

  IF v_revision IS NULL THEN
    RAISE EXCEPTION 'catalog_revision_tenant_missing'
      USING ERRCODE='23503';
  END IF;
  RETURN v_revision;
END;
$$;
REVOKE ALL ON FUNCTION item_core_internal.bump_item_catalog_revision(uuid)
  FROM PUBLIC,anon,authenticated;

-- POS read contract: lock the revision row against cooperating catalog
-- writers, then obtain one internally consistent full JSON snapshot.
CREATE OR REPLACE FUNCTION public.pos_pull_item_catalog_v2(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_revision bigint;
  v_snapshot_id uuid;
  v_items jsonb;
  v_units jsonb;
  v_rules jsonb;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id,p_device_id,p_device_secret
  );
  SELECT revision,snapshot_id
  INTO v_revision,v_snapshot_id
  FROM public.item_catalog_revisions
  WHERE restaurant_id=p_restaurant_id
  FOR SHARE;
  IF v_revision IS NULL THEN
    RAISE EXCEPTION 'catalog_revision_not_initialized'
      USING ERRCODE='23503';
  END IF;

  -- A missing base unit or broken active rule MUST fail the full pull
  -- rather than send an incomplete catalog that deletes local rows.
  IF EXISTS (
    SELECT 1 FROM public.items i
    WHERE i.restaurant_id=p_restaurant_id
      AND NOT EXISTS (
        SELECT 1 FROM public.item_units u
        WHERE u.restaurant_id=i.restaurant_id AND u.item_id=i.id
          AND u.unit_id=i.base_unit_id AND u.is_active
          AND u.quantity_in_base=1
      )
  ) THEN
    RAISE EXCEPTION 'catalog_missing_base_unit'
      USING ERRCODE='23514';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.item_consumption_rules r
    JOIN public.items consumed ON consumed.id=r.consumed_item_id
      AND consumed.restaurant_id=r.restaurant_id
    WHERE r.restaurant_id=p_restaurant_id AND r.is_active
      AND (consumed.item_type='service' OR NOT consumed.is_active
        OR NOT EXISTS(
          SELECT 1 FROM public.item_units u
          WHERE u.restaurant_id=r.restaurant_id
            AND u.item_id=r.consumed_item_id
            AND u.unit_id=r.unit_id AND u.is_active
        ))
  ) THEN
    RAISE EXCEPTION 'catalog_invalid_consumption_rule'
      USING ERRCODE='23514';
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'restaurant_id',i.restaurant_id,
    'id',i.id,'code',i.code,'name',i.name,
    'item_type',i.item_type,'base_unit_id',i.base_unit_id,
    'can_sell',i.can_sell,'visible_in_pos',i.visible_in_pos,
    'is_active',i.is_active
  ) ORDER BY i.code,i.id),'[]'::jsonb)
  INTO v_items
  FROM public.items i
  WHERE i.restaurant_id=p_restaurant_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'restaurant_id',u.restaurant_id,
    'item_id',u.item_id,'unit_id',u.unit_id,
    'quantity_in_base',u.quantity_in_base::text
  ) ORDER BY u.item_id,u.unit_id),'[]'::jsonb)
  INTO v_units
  FROM public.item_units u
  JOIN public.items i ON i.restaurant_id=u.restaurant_id AND i.id=u.item_id
  WHERE u.restaurant_id=p_restaurant_id AND u.is_active;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'restaurant_id',r.restaurant_id,'id',r.id,
    'source_item_id',r.source_item_id,
    'consumed_item_id',r.consumed_item_id,
    'unit_id',r.unit_id,'scope',r.scope,
    'quantity',r.quantity::text
  ) ORDER BY r.id),'[]'::jsonb)
  INTO v_rules
  FROM public.item_consumption_rules r
  WHERE r.restaurant_id=p_restaurant_id AND r.is_active;

  RETURN jsonb_build_object(
    'contract_version',2,
    'restaurant_id',p_restaurant_id,
    'snapshot_complete',true,
    'snapshot_id',v_snapshot_id,
    'revision',v_revision,
    'items',v_items,
    'item_units',v_units,
    'consumption_rules',v_rules
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_pull_item_catalog_v2(uuid,uuid,text)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pos_pull_item_catalog_v2(uuid,uuid,text)
  TO authenticated;

-- Review before cutover: final private helper privileges, JWT/device auth,
-- source data quality, all catalog writer revision locks, unsynced queues,
-- old clients blocked, and atomic Drift transaction. No migration here.
