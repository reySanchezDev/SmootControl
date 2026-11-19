-- Preserve catalog refresh revisions while allowing sale-time price snapshots
-- to sync after harmless commercial edits. Operational catalog edits stay strict.
BEGIN;

CREATE TABLE public.item_catalog_revision_events (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  revision bigint NOT NULL CHECK (revision > 0),
  snapshot_id uuid NOT NULL,
  change_kind text NOT NULL CHECK (
    change_kind IN ('baseline', 'commercial', 'operational')
  ),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (restaurant_id, revision)
);
ALTER TABLE public.item_catalog_revision_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.item_catalog_revision_events FROM PUBLIC, anon, authenticated;

-- The installation point is recorded as a non-replayable baseline. Older
-- queued snapshots lack trustworthy revision history and remain fail-closed.
INSERT INTO public.item_catalog_revision_events(
  restaurant_id, revision, snapshot_id, change_kind
)
SELECT restaurant_id, revision, snapshot_id, 'baseline'
FROM public.item_catalog_revisions
ON CONFLICT (restaurant_id, revision) DO NOTHING;

CREATE OR REPLACE FUNCTION item_core_internal.bump_item_catalog_revision(
  p_restaurant_id uuid
) RETURNS TABLE (revision bigint, snapshot_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_change_kind text;
BEGIN
  v_change_kind := COALESCE(
    NULLIF(current_setting('item_core.catalog_revision_change_kind', true), ''),
    'operational'
  );
  IF v_change_kind NOT IN ('commercial', 'operational') THEN
    v_change_kind := 'operational';
  END IF;

  UPDATE public.item_catalog_revisions r
  SET revision = r.revision + 1, snapshot_id = gen_random_uuid(), updated_at = now()
  WHERE r.restaurant_id = p_restaurant_id
  RETURNING r.revision, r.snapshot_id INTO revision, snapshot_id;
  IF revision IS NULL THEN
    INSERT INTO public.item_catalog_revisions(restaurant_id)
    VALUES (p_restaurant_id)
    RETURNING item_catalog_revisions.revision, item_catalog_revisions.snapshot_id
      INTO revision, snapshot_id;
  END IF;

  INSERT INTO public.item_catalog_revision_events(
    restaurant_id, revision, snapshot_id, change_kind
  ) VALUES (p_restaurant_id, revision, snapshot_id, v_change_kind);
  PERFORM set_config('item_core.catalog_revision_change_kind', '', true);
  RETURN NEXT;
END;
$$;
REVOKE ALL ON FUNCTION item_core_internal.bump_item_catalog_revision(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION item_core_internal.classify_item_catalog_edit()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_current_kind text := current_setting(
    'item_core.catalog_revision_change_kind', true
  );
  v_is_commercial boolean := false;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    v_is_commercial :=
      (to_jsonb(NEW) - ARRAY[
        'name', 'category_id', 'commercial_code', 'base_unit_price',
        'base_unit_cost', 'updated_at'
      ]) IS NOT DISTINCT FROM
      (to_jsonb(OLD) - ARRAY[
        'name', 'category_id', 'commercial_code', 'base_unit_price',
        'base_unit_cost', 'updated_at'
      ]);
  END IF;
  IF v_current_kind = 'operational' OR NOT v_is_commercial THEN
    PERFORM set_config(
      'item_core.catalog_revision_change_kind', 'operational', true
    );
  ELSE
    PERFORM set_config(
      'item_core.catalog_revision_change_kind', 'commercial', true
    );
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION item_core_internal.classify_item_catalog_edit()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS items_classify_catalog_revision_change ON public.items;
CREATE TRIGGER items_classify_catalog_revision_change
AFTER INSERT OR UPDATE OR DELETE ON public.items
FOR EACH ROW EXECUTE FUNCTION item_core_internal.classify_item_catalog_edit();

-- For stale snapshots, require a complete chain of explicitly commercial-only
-- revisions. Unknown, missing, recipe, stock, unit, or capability changes fail closed.
DO $migration$
DECLARE
  definition text;
  marker text := $marker$  IF p_payload ? 'item_catalog_revision' OR
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
  END IF;$marker$;
  replacement text := $replacement$  IF p_payload ? 'item_catalog_revision' OR
     p_payload ? 'item_catalog_snapshot_id' OR
     p_payload ? 'item_catalog_contract_version' THEN
    IF COALESCE((p_payload ->> 'item_catalog_contract_version')::integer, 0) <> 3
       OR NULLIF(p_payload ->> 'item_catalog_revision', '') IS NULL
       OR NULLIF(p_payload ->> 'item_catalog_snapshot_id', '') IS NULL THEN
      RAISE EXCEPTION 'pos_catalog_revision_stale_refresh_required'
        USING ERRCODE = '40001';
    END IF;

    -- An already accepted queue entry must remain idempotent even if the
    -- catalog changed after the server committed the first attempt.
    IF NOT EXISTS (
      SELECT 1 FROM public.sales s
      WHERE s.restaurant_id = p_restaurant_id
        AND s.local_id = COALESCE(
          NULLIF(p_payload -> 'sale' ->> 'local_id', ''),
          p_payload -> 'sale' ->> 'id'
        )
    ) AND NOT EXISTS (
      SELECT 1
      FROM public.item_catalog_revisions current_revision
      JOIN public.item_catalog_revision_events source_event
        ON source_event.restaurant_id = current_revision.restaurant_id
       AND source_event.revision =
           (p_payload ->> 'item_catalog_revision')::bigint
       AND source_event.snapshot_id =
           (p_payload ->> 'item_catalog_snapshot_id')::uuid
      WHERE current_revision.restaurant_id = p_restaurant_id
        AND source_event.revision <= current_revision.revision
        AND (
          source_event.revision = current_revision.revision
          OR EXISTS (
            SELECT 1
            FROM public.item_catalog_revision_events changes
            WHERE changes.restaurant_id = p_restaurant_id
              AND changes.revision > source_event.revision
              AND changes.revision <= current_revision.revision
            GROUP BY changes.restaurant_id
            HAVING count(*) = current_revision.revision - source_event.revision
              AND bool_and(changes.change_kind = 'commercial')
          )
        )
    ) THEN
      RAISE EXCEPTION 'pos_catalog_revision_stale_refresh_required'
        USING ERRCODE = '40001';
    END IF;
  END IF;$replacement$;
BEGIN
  SELECT pg_get_functiondef(
    'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure
  ) INTO definition;
  IF position(marker IN definition) = 0 THEN
    RAISE EXCEPTION 'pos_sale_revision_guard_marker_missing';
  END IF;
  EXECUTE replace(definition, marker, replacement);
END;
$migration$;

COMMIT;
