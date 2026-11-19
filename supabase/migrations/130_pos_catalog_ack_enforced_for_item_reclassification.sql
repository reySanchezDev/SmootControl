-- Fail closed for unversioned/stale operations from upgraded devices and
-- prevent class transitions until every active terminal has current catalog.
BEGIN;

CREATE OR REPLACE FUNCTION item_core_internal.assert_pos_catalog_ack_current(
  p_restaurant_id uuid
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_revision bigint;
  v_snapshot_id uuid;
BEGIN
  SELECT revision, snapshot_id INTO v_revision, v_snapshot_id
  FROM public.item_catalog_revisions
  WHERE restaurant_id = p_restaurant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'item_catalog_revision_not_initialized';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.pos_devices d
    WHERE d.restaurant_id = p_restaurant_id AND d.is_active
      AND (d.item_catalog_contract_version IS DISTINCT FROM 3
        OR d.item_catalog_revision IS DISTINCT FROM v_revision
        OR d.item_catalog_snapshot_id IS DISTINCT FROM v_snapshot_id)
  ) THEN
    RAISE EXCEPTION 'item_class_change_requires_current_pos_catalog_ack'
      USING ERRCODE = '55000';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION item_core_internal.assert_pos_catalog_ack_current(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION item_core_internal.guard_item_class_pos_ack()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.item_class IS DISTINCT FROM OLD.item_class THEN
    PERFORM item_core_internal.assert_pos_catalog_ack_current(
      NEW.restaurant_id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS items_pos_catalog_ack_before_class_change
  ON public.items;
CREATE TRIGGER items_pos_catalog_ack_before_class_change
BEFORE UPDATE OF item_class ON public.items
FOR EACH ROW EXECUTE FUNCTION item_core_internal.guard_item_class_pos_ack();

REVOKE ALL ON FUNCTION item_core_internal.guard_item_class_pos_ack()
  FROM PUBLIC, anon, authenticated;

-- Once a device has acknowledged V3, it must never send an unversioned sale.
DO $migration$
DECLARE
  definition text;
  marker text := $$  IF p_payload ? 'item_catalog_revision' OR
     p_payload ? 'item_catalog_snapshot_id' OR
     p_payload ? 'item_catalog_contract_version' THEN$$;
  replacement text := $$  IF EXISTS (
    SELECT 1 FROM public.pos_devices d
    WHERE d.id = p_device_id AND d.restaurant_id = p_restaurant_id
      AND d.item_catalog_contract_version = 3
  ) AND NOT (
    p_payload ? 'item_catalog_revision' AND
    p_payload ? 'item_catalog_snapshot_id' AND
    p_payload ? 'item_catalog_contract_version'
  ) THEN
    RAISE EXCEPTION 'pos_sale_catalog_identity_required'
      USING ERRCODE = '40001';
  END IF;

  IF p_payload ? 'item_catalog_revision' OR
     p_payload ? 'item_catalog_snapshot_id' OR
     p_payload ? 'item_catalog_contract_version' THEN$$;
BEGIN
  SELECT pg_get_functiondef(
    'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure
  ) INTO definition;
  IF position(marker IN definition) = 0 THEN
    RAISE EXCEPTION 'pos_sale_catalog_identity_guard_marker_missing';
  END IF;
  EXECUTE replace(definition, marker, replacement);
END;
$migration$;

COMMIT;
