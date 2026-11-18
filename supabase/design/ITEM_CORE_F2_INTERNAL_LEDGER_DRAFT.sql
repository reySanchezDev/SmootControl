-- KIVO F2 INTERNAL STOCK ENGINE - UNDEPLOYED DESIGN DRAFT
-- Do not move to supabase/migrations, do not run on the operating DB.
-- Requires F1 DDL+RPC. An isolated test must validate the replacement.
-- The single internal engine may be called only from SECURITY DEFINER RPCs
-- owned by the same trusted role after those RPCs authorize their caller.
-- Never grant USAGE on this schema or EXECUTE on this function to clients.

CREATE SCHEMA IF NOT EXISTS item_core_internal;
REVOKE ALL ON SCHEMA item_core_internal FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION item_core_internal.post_movement(
  p_id text,
  p_restaurant_id uuid,
  p_item_id uuid,
  p_movement_type text,
  p_quantity_delta numeric,
  p_source_type text,
  p_source_id text,
  p_operation_key text,
  p_unit_cost_base numeric,
  p_reversal_of_id text,
  p_device_id uuid,
  p_actor_id uuid,
  p_occurred_at timestamptz
)
RETURNS public.item_ledger_entries
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
SET row_security = off
AS $$
DECLARE
  v_item public.items;
  v_existing public.item_ledger_entries;
  v_original public.item_ledger_entries;
  v_result public.item_ledger_entries;
  v_current numeric;
  v_digest text;
BEGIN
  IF p_id IS NULL OR length(btrim(p_id)) = 0
     OR p_restaurant_id IS NULL OR p_item_id IS NULL
     OR p_actor_id IS NULL OR p_occurred_at IS NULL
     OR p_quantity_delta IS NULL OR p_quantity_delta = 0
     OR p_unit_cost_base IS NULL OR p_unit_cost_base < 0
     OR p_source_type IS NULL OR length(btrim(p_source_type)) = 0
     OR p_source_id IS NULL OR length(btrim(p_source_id)) = 0
     OR p_operation_key IS NULL OR length(btrim(p_operation_key)) = 0
     OR p_movement_type NOT IN (
       'opening', 'purchase', 'sale', 'recipe_consumption',
       'packaging_consumption', 'staff_consumption', 'adjustment', 'reversal'
     )
  THEN
    RAISE EXCEPTION 'invalid_internal_movement_payload'
      USING ERRCODE = '22023';
  END IF;

  IF p_device_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.pos_devices d
    WHERE d.id = p_device_id AND d.restaurant_id = p_restaurant_id
      AND d.is_active = true
  ) THEN
    RAISE EXCEPTION 'device_not_found_or_inactive' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_item
  FROM public.items i
  WHERE i.id = p_item_id AND i.restaurant_id = p_restaurant_id
  FOR SHARE;

  IF v_item.id IS NULL OR NOT v_item.is_active
     OR v_item.item_type <> 'inventory'
  THEN
    RAISE EXCEPTION 'item_not_active_or_not_inventory'
      USING ERRCODE = '23514';
  END IF;

  v_digest := public.item_movement_request_digest(
    p_id, p_restaurant_id, p_item_id, p_movement_type,
    p_quantity_delta, p_source_type, p_source_id, p_operation_key,
    p_unit_cost_base, p_reversal_of_id, p_device_id,
    p_actor_id, p_occurred_at
  );

  -- One row lock serializes every movement for this item. Insert provisional
  -- balance inside this transaction, then lock before the idempotency check.
  INSERT INTO public.item_stock(restaurant_id, item_id)
  VALUES(p_restaurant_id, p_item_id)
  ON CONFLICT DO NOTHING;

  SELECT s.quantity_on_hand INTO v_current
  FROM public.item_stock s
  WHERE s.restaurant_id = p_restaurant_id AND s.item_id = p_item_id
  FOR UPDATE;

  SELECT * INTO v_existing
  FROM public.item_ledger_entries e
  WHERE e.restaurant_id = p_restaurant_id
    AND e.operation_key = p_operation_key
  FOR UPDATE;

  IF v_existing.id IS NOT NULL THEN
    IF v_existing.id <> p_id OR v_existing.request_digest <> v_digest
    THEN
      RAISE EXCEPTION 'idempotency_payload_mismatch'
        USING ERRCODE = '23514';
    END IF;
    RETURN v_existing;
  END IF;

  IF p_movement_type = 'reversal' THEN
    IF p_reversal_of_id IS NULL THEN
      RAISE EXCEPTION 'reversal_requires_original' USING ERRCODE = '23514';
    END IF;
    SELECT * INTO v_original
    FROM public.item_ledger_entries e
    WHERE e.id = p_reversal_of_id
    FOR SHARE;
    IF v_original.id IS NULL
       OR v_original.restaurant_id <> p_restaurant_id
       OR v_original.item_id <> p_item_id
       OR v_original.movement_type = 'reversal'
       OR p_quantity_delta <> -v_original.quantity_delta
       OR p_unit_cost_base <> v_original.unit_cost_base
    THEN
      RAISE EXCEPTION 'invalid_reversal_or_original_snapshot'
        USING ERRCODE = '23514';
    END IF;
  ELSIF p_reversal_of_id IS NOT NULL THEN
    RAISE EXCEPTION 'non_reversal_has_original' USING ERRCODE = '23514';
  END IF;

  IF v_current + p_quantity_delta < 0 THEN
    RAISE EXCEPTION 'insufficient_stock' USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.item_ledger_entries (
    id, restaurant_id, item_id, movement_type, quantity_delta,
    unit_cost_base, source_type, source_id, operation_key,
    request_digest, reversal_of_id, device_id, actor_id, occurred_at
  ) VALUES (
    p_id, p_restaurant_id, p_item_id, p_movement_type,
    p_quantity_delta, p_unit_cost_base, p_source_type, p_source_id,
    p_operation_key, v_digest, p_reversal_of_id, p_device_id,
    p_actor_id, p_occurred_at
  ) RETURNING * INTO v_result;

  UPDATE public.item_stock
  SET quantity_on_hand = v_current + p_quantity_delta,
      version = version + 1,
      updated_at = now()
  WHERE restaurant_id = p_restaurant_id AND item_id = p_item_id;

  IF (
    SELECT s.quantity_on_hand FROM public.item_stock s
    WHERE s.restaurant_id = p_restaurant_id AND s.item_id = p_item_id
  ) <> (
    SELECT coalesce(sum(e.quantity_delta),0)
    FROM public.item_ledger_entries e
    WHERE e.restaurant_id = p_restaurant_id AND e.item_id = p_item_id
  ) THEN
    RAISE EXCEPTION 'stock_projection_mismatch' USING ERRCODE = '23514';
  END IF;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION item_core_internal.post_movement(
  text, uuid, uuid, text, numeric, text, text, text, numeric,
  text, uuid, uuid, timestamptz
) FROM PUBLIC, anon, authenticated;

-- Replace ONLY the public inventory-admin wrapper, not its signature.
-- This makes the admin and future POS RPCs share a single stock engine.
CREATE OR REPLACE FUNCTION public.apply_item_movement(
  p_id text, p_restaurant_id uuid, p_item_id uuid,
  p_movement_type text, p_quantity_delta numeric,
  p_source_type text, p_source_id text, p_operation_key text,
  p_request_digest text, p_unit_cost_base numeric DEFAULT 0,
  p_reversal_of_id text DEFAULT NULL, p_device_id uuid DEFAULT NULL,
  p_actor_id uuid DEFAULT NULL, p_occurred_at timestamptz DEFAULT now()
)
RETURNS public.item_ledger_entries
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_digest text;
BEGIN
  IF NOT public.app_item_has_write_access(
    p_restaurant_id, 'inventario.gestionar'
  ) THEN
    RAISE EXCEPTION 'movement_not_authorized' USING ERRCODE = '42501';
  END IF;
  IF v_actor IS NULL OR
     (p_actor_id IS NOT NULL AND p_actor_id <> v_actor) THEN
    RAISE EXCEPTION 'actor_mismatch' USING ERRCODE = '42501';
  END IF;
  v_digest := public.item_movement_request_digest(
    p_id, p_restaurant_id, p_item_id, p_movement_type,
    p_quantity_delta, p_source_type, p_source_id, p_operation_key,
    p_unit_cost_base, p_reversal_of_id, p_device_id,
    v_actor, p_occurred_at
  );
  IF p_request_digest IS DISTINCT FROM v_digest THEN
    RAISE EXCEPTION 'request_digest_mismatch' USING ERRCODE = '23514';
  END IF;

  RETURN item_core_internal.post_movement(
    p_id, p_restaurant_id, p_item_id, p_movement_type,
    p_quantity_delta, p_source_type, p_source_id, p_operation_key,
    p_unit_cost_base, p_reversal_of_id, p_device_id,
    v_actor, p_occurred_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.apply_item_movement(
  text,uuid,uuid,text,numeric,text,text,text,text,
  numeric,text,uuid,uuid,timestamptz
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_item_movement(
  text,uuid,uuid,text,numeric,text,text,text,text,
  numeric,text,uuid,uuid,timestamptz
) TO authenticated;

-- WARNING: POS v2 must validate device credentials and open cash session
-- BEFORE calling item_core_internal.post_movement from a trusted definer.
-- No direct client path may ever invoke that private function.
