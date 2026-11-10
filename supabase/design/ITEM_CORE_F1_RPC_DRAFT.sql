-- KIVO ITEM CORE / F1 RPC REVIEW DRAFT
-- DO NOT EXECUTE on the principal lab or production.
-- Requires ITEM_CORE_F1_DDL_DRAFT.sql in an isolated database.
-- Authorization is based on request.jwt.claims; direct client DML stays revoked.

CREATE OR REPLACE FUNCTION public.app_item_has_write_access(p_restaurant_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_catalog
AS $$
DECLARE claims jsonb;
BEGIN
  claims := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb;
  RETURN (claims->>'role' = 'service_role')
    OR (claims->>'restaurant_id' = p_restaurant_id::text
      AND COALESCE((claims->'permissions') ? 'articulos.gestionar', false));
EXCEPTION WHEN others THEN
  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_upsert_item(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS public.items
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  result public.items;
  requested_id uuid;
  existing_id uuid;
  item_code text;
  item_name text;
  class_id uuid;
  unit_json jsonb;
BEGIN
  IF NOT public.app_item_has_write_access(p_restaurant_id) THEN
    RAISE EXCEPTION 'item_write_not_authorized';
  END IF;
  IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
    RAISE EXCEPTION 'invalid_item_payload';
  END IF;

  requested_id := NULLIF(p_payload->>'id', '')::uuid;
  item_code := btrim(p_payload->>'code');
  item_name := btrim(p_payload->>'name');
  IF item_code IS NULL OR length(item_code) NOT BETWEEN 1 AND 64 THEN
    RAISE EXCEPTION 'invalid_item_code';
  END IF;
  IF item_name IS NULL OR length(item_name) NOT BETWEEN 1 AND 250 THEN
    RAISE EXCEPTION 'invalid_item_name';
  END IF;
  IF p_payload->>'item_type' NOT IN ('inventory', 'non_inventory', 'service') THEN
    RAISE EXCEPTION 'invalid_item_type';
  END IF;

  IF requested_id IS NOT NULL THEN
    SELECT id INTO existing_id FROM public.items
    WHERE id = requested_id AND restaurant_id = p_restaurant_id FOR UPDATE;
    IF existing_id IS NULL THEN
      RAISE EXCEPTION 'item_not_found_or_cross_tenant';
    END IF;
  ELSE
    SELECT id INTO existing_id FROM public.items
    WHERE restaurant_id = p_restaurant_id
      AND lower(btrim(code)) = lower(item_code) FOR UPDATE;
  END IF;

  IF existing_id IS NULL THEN
    INSERT INTO public.items (
      restaurant_id, code, name, item_type, category_id, base_unit_id,
      base_unit_cost, base_unit_price, can_sell, can_purchase, visible_in_pos,
      uses_recipe, send_to_kitchen, is_active
    ) VALUES (
      p_restaurant_id, item_code, item_name, p_payload->>'item_type',
      NULLIF(p_payload->>'category_id', '')::uuid,
      (p_payload->>'base_unit_id')::uuid,
      COALESCE((p_payload->>'base_unit_cost')::numeric, 0),
      COALESCE((p_payload->>'base_unit_price')::numeric, 0),
      COALESCE((p_payload->>'can_sell')::boolean, false),
      COALESCE((p_payload->>'can_purchase')::boolean, false),
      COALESCE((p_payload->>'visible_in_pos')::boolean, false),
      COALESCE((p_payload->>'uses_recipe')::boolean, false),
      COALESCE((p_payload->>'send_to_kitchen')::boolean, false),
      COALESCE((p_payload->>'is_active')::boolean, true)
    ) RETURNING * INTO result;
  ELSE
    UPDATE public.items SET
      code = item_code, name = item_name, item_type = p_payload->>'item_type',
      category_id = NULLIF(p_payload->>'category_id', '')::uuid,
      base_unit_id = (p_payload->>'base_unit_id')::uuid,
      base_unit_cost = COALESCE((p_payload->>'base_unit_cost')::numeric, 0),
      base_unit_price = COALESCE((p_payload->>'base_unit_price')::numeric, 0),
      can_sell = COALESCE((p_payload->>'can_sell')::boolean, false),
      can_purchase = COALESCE((p_payload->>'can_purchase')::boolean, false),
      visible_in_pos = COALESCE((p_payload->>'visible_in_pos')::boolean, false),
      uses_recipe = COALESCE((p_payload->>'uses_recipe')::boolean, false),
      send_to_kitchen = COALESCE((p_payload->>'send_to_kitchen')::boolean, false),
      is_active = COALESCE((p_payload->>'is_active')::boolean, true),
      updated_at = now()
    WHERE id = existing_id AND restaurant_id = p_restaurant_id
    RETURNING * INTO result;
  END IF;

  INSERT INTO public.item_units(restaurant_id, item_id, unit_id, quantity_in_base)
  VALUES (p_restaurant_id, result.id, result.base_unit_id, 1)
  ON CONFLICT (restaurant_id, item_id, unit_id)
  DO UPDATE SET quantity_in_base = 1, is_active = true;

  IF p_payload ? 'units' THEN
    FOR unit_json IN SELECT value FROM jsonb_array_elements(p_payload->'units') LOOP
      IF NOT EXISTS (
        SELECT 1 FROM public.measurement_units u
        WHERE u.id = (unit_json->>'unit_id')::uuid
          AND (u.restaurant_id IS NULL OR u.restaurant_id = p_restaurant_id)
      ) THEN
        RAISE EXCEPTION 'unit_not_found_or_cross_tenant';
      END IF;
      INSERT INTO public.item_units(
        restaurant_id, item_id, unit_id, quantity_in_base,
        is_purchase, is_sale
      ) VALUES (
        p_restaurant_id, result.id, (unit_json->>'unit_id')::uuid,
        (unit_json->>'quantity_in_base')::numeric,
        COALESCE((unit_json->>'is_purchase')::boolean, false),
        COALESCE((unit_json->>'is_sale')::boolean, false)
      ) ON CONFLICT (restaurant_id, item_id, unit_id) DO UPDATE SET
        quantity_in_base = EXCLUDED.quantity_in_base,
        is_purchase = EXCLUDED.is_purchase,
        is_sale = EXCLUDED.is_sale,
        is_active = true;
    END LOOP;
  END IF;

  IF p_payload ? 'classification_ids' THEN
    DELETE FROM public.item_classification_links
    WHERE restaurant_id = p_restaurant_id AND item_id = result.id;
    FOR class_id IN
      SELECT value::uuid FROM jsonb_array_elements_text(p_payload->'classification_ids')
    LOOP
      IF NOT EXISTS (
        SELECT 1 FROM public.item_classifications c
        WHERE c.id = class_id AND c.restaurant_id = p_restaurant_id
      ) THEN
        RAISE EXCEPTION 'classification_not_found_or_cross_tenant';
      END IF;
      INSERT INTO public.item_classification_links(
        restaurant_id, item_id, classification_id
      ) VALUES (p_restaurant_id, result.id, class_id);
    END LOOP;
  END IF;
  RETURN result;
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'item_code_or_unit_conflict';
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_item_movement(
  p_id text, p_restaurant_id uuid, p_item_id uuid, p_movement_type text,
  p_quantity_delta numeric, p_source_type text, p_source_id text,
  p_operation_key text, p_request_digest text, p_unit_cost_base numeric = 0,
  p_reversal_of_id text = NULL, p_device_id uuid = NULL,
  p_actor_id uuid = NULL, p_occurred_at timestamptz = now()
)
RETURNS public.item_ledger_entries
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  item_row public.items;
  prior public.item_ledger_entries;
  original public.item_ledger_entries;
  result public.item_ledger_entries;
  current_qty numeric;
BEGIN
  IF NOT public.app_item_has_write_access(p_restaurant_id) THEN
    RAISE EXCEPTION 'movement_not_authorized';
  END IF;
  IF p_quantity_delta = 0 OR length(btrim(p_operation_key)) = 0
     OR length(btrim(p_request_digest)) = 0 THEN
    RAISE EXCEPTION 'invalid_movement_payload';
  END IF;
  SELECT * INTO prior FROM public.item_ledger_entries
  WHERE restaurant_id = p_restaurant_id AND operation_key = p_operation_key
  FOR UPDATE;
  IF prior.id IS NOT NULL THEN
    IF prior.request_digest <> p_request_digest THEN
      RAISE EXCEPTION 'idempotency_payload_mismatch';
    END IF;
    RETURN prior;
  END IF;

  SELECT * INTO item_row FROM public.items
  WHERE id = p_item_id AND restaurant_id = p_restaurant_id FOR SHARE;
  IF item_row.id IS NULL THEN RAISE EXCEPTION 'item_not_found_or_cross_tenant'; END IF;
  IF item_row.item_type <> 'inventory' THEN
    RAISE EXCEPTION 'item_type_has_no_physical_stock';
  END IF;
  IF p_movement_type = 'reversal' THEN
    IF p_reversal_of_id IS NULL THEN RAISE EXCEPTION 'reversal_requires_original'; END IF;
    SELECT * INTO original FROM public.item_ledger_entries
    WHERE id = p_reversal_of_id FOR SHARE;
    IF original.id IS NULL OR original.restaurant_id <> p_restaurant_id
       OR original.item_id <> p_item_id OR original.movement_type = 'reversal' THEN
      RAISE EXCEPTION 'invalid_reversal_original';
    END IF;
    IF p_quantity_delta <> -original.quantity_delta THEN
      RAISE EXCEPTION 'reversal_quantity_mismatch';
    END IF;
  ELSIF p_reversal_of_id IS NOT NULL THEN
    RAISE EXCEPTION 'only_reversal_can_reference_original';
  END IF;

  INSERT INTO public.item_stock(restaurant_id, item_id)
  VALUES (p_restaurant_id, p_item_id) ON CONFLICT DO NOTHING;
  SELECT quantity_on_hand INTO current_qty FROM public.item_stock
  WHERE restaurant_id = p_restaurant_id AND item_id = p_item_id FOR UPDATE;
  IF current_qty + p_quantity_delta < 0 THEN RAISE EXCEPTION 'insufficient_stock'; END IF;

  INSERT INTO public.item_ledger_entries(
    id, restaurant_id, item_id, movement_type, quantity_delta, unit_cost_base,
    source_type, source_id, operation_key, request_digest, reversal_of_id,
    device_id, actor_id, occurred_at
  ) VALUES (
    p_id, p_restaurant_id, p_item_id, p_movement_type, p_quantity_delta,
    p_unit_cost_base, p_source_type, p_source_id, p_operation_key,
    p_request_digest, p_reversal_of_id, p_device_id, p_actor_id, p_occurred_at
  ) RETURNING * INTO result;
  UPDATE public.item_stock SET quantity_on_hand = current_qty + p_quantity_delta,
    version = version + 1, updated_at = now()
  WHERE restaurant_id = p_restaurant_id AND item_id = p_item_id;
  RETURN result;
EXCEPTION WHEN unique_violation THEN
  SELECT * INTO prior FROM public.item_ledger_entries
  WHERE restaurant_id = p_restaurant_id AND operation_key = p_operation_key;
  IF prior.id IS NOT NULL AND prior.request_digest = p_request_digest THEN RETURN prior; END IF;
  RAISE EXCEPTION 'movement_conflict';
END;
$$;

REVOKE ALL ON FUNCTION public.app_upsert_item(uuid, jsonb),
  public.apply_item_movement(text, uuid, uuid, text, numeric, text, text,
    text, text, numeric, text, uuid, uuid, timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_upsert_item(uuid, jsonb),
  public.apply_item_movement(text, uuid, uuid, text, numeric, text, text,
    text, text, numeric, text, uuid, uuid, timestamptz) TO authenticated;

