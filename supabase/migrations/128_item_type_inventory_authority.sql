-- Makes item_type authoritative for inventory tracking.
BEGIN;

DO $preflight$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.items item
    WHERE item.item_type = 'inventory'
      AND NOT item.tracks_inventory
      AND (
        EXISTS (
          SELECT 1 FROM public.inventory_stock stock
          WHERE stock.restaurant_id = item.restaurant_id
            AND stock.item_id = item.id
            AND stock.quantity_on_hand <> 0
        )
        OR EXISTS (
          SELECT 1 FROM public.inventory_movements movement
          WHERE movement.restaurant_id = item.restaurant_id
            AND movement.item_id = item.id
        )
      )
  ) THEN
    RAISE EXCEPTION 'item_type_stock_mismatch_requires_reconciliation';
  END IF;
END;
$preflight$;

UPDATE public.items
SET tracks_inventory = (item_type = 'inventory')
WHERE tracks_inventory IS DISTINCT FROM (item_type = 'inventory');

CREATE OR REPLACE FUNCTION public.derive_item_inventory_tracking()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.tracks_inventory := (NEW.item_type = 'inventory');
  IF TG_OP = 'UPDATE'
     AND OLD.item_type = 'inventory'
     AND NEW.item_type <> 'inventory'
     AND EXISTS (
       SELECT 1 FROM public.inventory_stock
       WHERE restaurant_id = OLD.restaurant_id
         AND item_id = OLD.id
         AND quantity_on_hand <> 0
     ) THEN
    RAISE EXCEPTION 'item_type_change_with_nonzero_stock'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS items_inventory_tracking_from_type ON public.items;
CREATE TRIGGER items_inventory_tracking_from_type
BEFORE INSERT OR UPDATE OF item_type, tracks_inventory ON public.items
FOR EACH ROW EXECUTE FUNCTION public.derive_item_inventory_tracking();

ALTER TABLE public.items
  DROP CONSTRAINT IF EXISTS items_type_inventory_contract;
ALTER TABLE public.items
  ADD CONSTRAINT items_type_inventory_contract
  CHECK (tracks_inventory = (item_type = 'inventory'));

REVOKE ALL ON FUNCTION public.derive_item_inventory_tracking() FROM PUBLIC;

ALTER FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  RENAME TO app_upsert_item_v2_pre_128;

CREATE FUNCTION public.app_upsert_item_v2(
  p_restaurant_id uuid,
  p_payload jsonb
) RETURNS public.items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN public.app_upsert_item_v2_pre_128(
    p_restaurant_id,
    p_payload - 'commercial_code'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.app_upsert_item_v2_pre_128(uuid, jsonb)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  TO authenticated;

COMMIT;
