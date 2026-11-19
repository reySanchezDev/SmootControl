-- Routes packaging items that no longer have a legacy packaging row through
-- the canonical item ledger. Existing legacy rows remain backward compatible.
BEGIN;

CREATE OR REPLACE FUNCTION item_core_internal.apply_canonical_packaging_movement(
  p_id text,
  p_restaurant_id uuid,
  p_item_id uuid,
  p_movement_type text,
  p_quantity_delta numeric,
  p_unit_cost numeric DEFAULT 0,
  p_reference_type text DEFAULT NULL,
  p_reference_id text DEFAULT NULL,
  p_user_id text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_created_at timestamptz DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_item public.items;
  v_movement_type text;
  v_current numeric;
  v_next numeric;
BEGIN
  IF p_id IS NULL OR btrim(p_id) = '' OR p_item_id IS NULL THEN
    RAISE EXCEPTION 'canonical_packaging_movement_identity_invalid'
      USING ERRCODE = '23502';
  END IF;
  SELECT * INTO v_item FROM public.items
  WHERE id = p_item_id AND restaurant_id = p_restaurant_id
    AND source_kind = 'packaging' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'canonical_packaging_item_not_found' USING ERRCODE = '23503';
  END IF;
  IF p_quantity_delta IS NULL OR p_quantity_delta = 0 THEN
    RAISE EXCEPTION 'canonical_packaging_quantity_invalid' USING ERRCODE = '23514';
  END IF;
  v_movement_type := CASE p_movement_type
    WHEN 'packaging_purchase' THEN 'purchase'
    WHEN 'packaging_sale' THEN 'sale'
    WHEN 'packaging_sale_void' THEN 'sale_void'
    ELSE p_movement_type
  END;
  IF v_movement_type NOT IN ('purchase', 'sale', 'sale_void', 'adjustment') THEN
    RAISE EXCEPTION 'canonical_packaging_movement_type_invalid'
      USING ERRCODE = '23514';
  END IF;
  IF EXISTS (SELECT 1 FROM public.inventory_movements WHERE id = p_id) THEN
    RETURN;
  END IF;

  IF v_item.tracks_inventory THEN
    INSERT INTO public.inventory_stock(
      restaurant_id, item_id, quantity_on_hand, created_at, updated_at
    ) VALUES (p_restaurant_id, p_item_id, 0, now(), now())
    ON CONFLICT (restaurant_id, item_id) DO NOTHING;
    SELECT quantity_on_hand INTO v_current FROM public.inventory_stock
    WHERE restaurant_id = p_restaurant_id AND item_id = p_item_id FOR UPDATE;
    v_next := COALESCE(v_current, 0) + p_quantity_delta;
    IF v_next < 0 THEN
      RAISE EXCEPTION 'Stock insuficiente para empaque canónico'
        USING ERRCODE = '23514';
    END IF;
  ELSE
    v_next := NULL;
  END IF;

  INSERT INTO public.inventory_movements(
    id, restaurant_id, item_id, movement_type, quantity_delta,
    reference_type, reference_id, user_id, notes, created_at, unit_cost
  ) VALUES (
    p_id, p_restaurant_id, p_item_id, v_movement_type, p_quantity_delta,
    p_reference_type, p_reference_id, p_user_id, p_notes,
    COALESCE(p_created_at, now()), COALESCE(p_unit_cost, 0)
  );
  IF v_item.tracks_inventory THEN
    UPDATE public.inventory_stock SET quantity_on_hand = v_next, updated_at = now()
    WHERE restaurant_id = p_restaurant_id AND item_id = p_item_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.filter_legacy_packaging_movements(
  p_restaurant_id uuid,
  p_payload jsonb
) RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(m.value), '[]'::jsonb)
  FROM jsonb_array_elements(COALESCE(p_payload, '[]'::jsonb)) m(value)
  WHERE EXISTS (
    SELECT 1 FROM public.packaging_items p
    WHERE p.id = NULLIF(m.value ->> 'packaging_item_id', '')::uuid
      AND p.restaurant_id = p_restaurant_id
  );
$$;

DO $migration$
DECLARE
  definition text;
  marker text := $$normalized := jsonb_set(
    normalized, '{inventory_movements}', '[]'::jsonb, true
  );$$;
  replacement text := $$normalized := jsonb_set(
    normalized, '{inventory_movements}', '[]'::jsonb, true
  );
  normalized := jsonb_set(
    normalized, '{packaging_movements}',
    public.filter_legacy_packaging_movements(
      p_restaurant_id, p_payload -> 'packaging_movements'
    ), true
  );$$;
  void_marker text := $$IF COALESCE(p_payload -> 'void', '{}'::jsonb) <> '{}'::jsonb OR
     COALESCE(p_payload -> 'sale' ->> 'status', '') = 'voided' THEN$$;
  void_replacement text := $$FOR movement IN SELECT value FROM jsonb_array_elements(
    COALESCE(p_payload -> 'packaging_movements', '[]'::jsonb)
  ) LOOP
    IF EXISTS (
      SELECT 1 FROM public.items i
      WHERE i.id = NULLIF(movement ->> 'packaging_item_id', '')::uuid
        AND i.restaurant_id = p_restaurant_id
        AND i.source_kind = 'packaging'
    ) AND NOT EXISTS (
      SELECT 1 FROM public.packaging_items p
      WHERE p.id = NULLIF(movement ->> 'packaging_item_id', '')::uuid
        AND p.restaurant_id = p_restaurant_id
    ) THEN
      PERFORM item_core_internal.apply_canonical_packaging_movement(
        movement ->> 'id', p_restaurant_id,
        NULLIF(movement ->> 'packaging_item_id', '')::uuid,
        movement ->> 'movement_type',
        (movement ->> 'quantity_delta')::numeric,
        COALESCE((movement ->> 'unit_cost')::numeric, 0),
        movement ->> 'reference_type', v_sale_id::text,
        movement ->> 'user_id', movement ->> 'notes',
        NULLIF(movement ->> 'created_at', '')::timestamptz
      );
    END IF;
  END LOOP;

  IF COALESCE(p_payload -> 'void', '{}'::jsonb) <> '{}'::jsonb OR
     COALESCE(p_payload -> 'sale' ->> 'status', '') = 'voided' THEN$$;
BEGIN
  SELECT pg_get_functiondef(
    'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure
  ) INTO definition;
  IF position(marker IN definition) = 0 OR position(void_marker IN definition) = 0 THEN
    RAISE EXCEPTION 'No se encontró el límite esperado del RPC POS';
  END IF;
  definition := replace(definition, marker, replacement);
  definition := replace(definition, void_marker, void_replacement);
  EXECUTE definition;
END;
$migration$;

REVOKE ALL ON FUNCTION public.filter_legacy_packaging_movements(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.filter_legacy_packaging_movements(uuid, jsonb)
  TO authenticated;

COMMIT;
