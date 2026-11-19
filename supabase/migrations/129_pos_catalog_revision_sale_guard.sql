-- Record catalog acknowledgements and reject sales built from a stale catalog.
-- A rejected sale remains in the device queue; no sale or movement is committed.
BEGIN;

ALTER TABLE public.pos_devices
  ADD COLUMN IF NOT EXISTS item_catalog_revision bigint,
  ADD COLUMN IF NOT EXISTS item_catalog_snapshot_id uuid,
  ADD COLUMN IF NOT EXISTS item_catalog_contract_version integer;

ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS item_catalog_revision bigint,
  ADD COLUMN IF NOT EXISTS item_catalog_snapshot_id uuid,
  ADD COLUMN IF NOT EXISTS item_catalog_contract_version integer;

CREATE OR REPLACE FUNCTION public.pos_ack_item_catalog_v2(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_revision bigint,
  p_snapshot_id uuid,
  p_contract_version integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_revision bigint;
  v_snapshot_id uuid;
BEGIN
  PERFORM public.assert_pos_device(
    p_restaurant_id, p_device_id, p_device_secret
  );
  SELECT revision, snapshot_id INTO v_revision, v_snapshot_id
  FROM public.item_catalog_revisions
  WHERE restaurant_id = p_restaurant_id FOR SHARE;
  IF p_revision IS DISTINCT FROM v_revision OR
     p_snapshot_id IS DISTINCT FROM v_snapshot_id OR
     p_contract_version <> 3 THEN
    RAISE EXCEPTION 'pos_catalog_ack_mismatch'
      USING ERRCODE = '40001';
  END IF;
  UPDATE public.pos_devices SET
    item_catalog_revision = p_revision,
    item_catalog_snapshot_id = p_snapshot_id,
    item_catalog_contract_version = p_contract_version,
    updated_at = now()
  WHERE id = p_device_id AND restaurant_id = p_restaurant_id;
  RETURN jsonb_build_object(
    'acknowledged', true,
    'revision', p_revision,
    'snapshot_id', p_snapshot_id,
    'contract_version', p_contract_version
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_ack_item_catalog_v2(
  uuid, uuid, text, bigint, uuid, integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pos_ack_item_catalog_v2(
  uuid, uuid, text, bigint, uuid, integer
) TO anon, authenticated;

-- Keep the existing snapshot shape and make the contract version explicit.
DO $migration$
DECLARE
  definition text;
  marker text := $$'contract_version', 2,$$;
BEGIN
  SELECT pg_get_functiondef(
    'public.pos_pull_item_catalog_v2(uuid,uuid,text)'::regprocedure
  ) INTO definition;
  IF position(marker IN definition) = 0 THEN
    RAISE EXCEPTION 'pos_item_catalog_contract_marker_missing';
  END IF;
  EXECUTE replace(definition, marker, $$'contract_version', 3,$$);
END;
$migration$;

-- Persist the accepted catalog identity on the sale for later audit/reversal.
DO $migration$
DECLARE
  definition text;
  marker text := $$  v_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;$$;
  replacement text := $$  v_sale_id := NULLIF(result ->> 'remote_id', '')::uuid;

  IF v_sale_id IS NOT NULL AND p_payload ? 'item_catalog_contract_version' THEN
    UPDATE public.sales SET
      item_catalog_revision = (p_payload ->> 'item_catalog_revision')::bigint,
      item_catalog_snapshot_id =
        (p_payload ->> 'item_catalog_snapshot_id')::uuid,
      item_catalog_contract_version =
        (p_payload ->> 'item_catalog_contract_version')::integer
    WHERE id = v_sale_id AND restaurant_id = p_restaurant_id;
  END IF;$$;
BEGIN
  SELECT pg_get_functiondef(
    'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure
  ) INTO definition;
  IF position(marker IN definition) = 0 THEN
    RAISE EXCEPTION 'pos_sale_identity_marker_missing';
  END IF;
  EXECUTE replace(definition, marker, replacement);
END;
$migration$;

-- Versioned clients may sync only while their catalog snapshot is still current.
-- Legacy queued operations remain compatible; they are never relabeled here.
DO $migration$
DECLARE
  definition text;
  marker text := $$  PERFORM public.assert_pos_device(
    p_restaurant_id, p_device_id, p_device_secret
  );$$;
  replacement text := $$  PERFORM public.assert_pos_device(
    p_restaurant_id, p_device_id, p_device_secret
  );

  IF p_payload ? 'item_catalog_revision' OR
     p_payload ? 'item_catalog_snapshot_id' OR
     p_payload ? 'item_catalog_contract_version' THEN
    IF COALESCE((p_payload ->> 'item_catalog_contract_version')::integer, 0) <> 3
       OR NOT EXISTS (
         SELECT 1 FROM public.item_catalog_revisions r
         WHERE r.restaurant_id = p_restaurant_id
           AND r.revision = (p_payload ->> 'item_catalog_revision')::bigint
           AND r.snapshot_id = (p_payload ->> 'item_catalog_snapshot_id')::uuid
       ) THEN
      RAISE EXCEPTION 'pos_catalog_revision_stale_refresh_required'
        USING ERRCODE = '40001';
    END IF;
  END IF;$$;
BEGIN
  SELECT pg_get_functiondef(
    'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure
  ) INTO definition;
  IF position(marker IN definition) = 0 THEN
    RAISE EXCEPTION 'pos_sale_device_assert_marker_missing';
  END IF;
  EXECUTE replace(definition, marker, replacement);
END;
$migration$;

COMMENT ON FUNCTION public.pos_ack_item_catalog_v2(
  uuid, uuid, text, bigint, uuid, integer
) IS 'Acknowledges a catalog snapshot only after the POS commits it locally.';

COMMIT;
