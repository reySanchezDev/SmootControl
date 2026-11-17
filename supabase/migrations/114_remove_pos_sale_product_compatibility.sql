-- Remove product-table compatibility from the canonical POS sale RPC.
DO $migration$
DECLARE definition text;
BEGIN
  SELECT pg_get_functiondef(oid) INTO definition
  FROM pg_proc
  WHERE proname = 'pos_sync_sale_v2' AND prokind = 'f'
    AND pg_get_function_identity_arguments(oid) =
      'p_restaurant_id uuid, p_device_id uuid, p_device_secret text, p_payload jsonb';
  definition := replace(definition,
    $$IF v_item_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = v_item_id AND p.restaurant_id = p_restaurant_id
    ) THEN
      legacy_lines := legacy_lines || jsonb_set(
        line, '{product_id}', to_jsonb(v_item_id::text), true
      );
    ELSE
      -- The historical core accepts a nullable product_id. The canonical
      -- identity is attached immediately after the idempotent core returns.
      legacy_lines := legacy_lines || jsonb_set(
        line, '{product_id}', 'null'::jsonb, true
      );
    END IF;$$,
    $$IF v_item_id IS NOT NULL THEN
      legacy_lines := legacy_lines || jsonb_set(
        line, '{product_id}', 'null'::jsonb, true
      );
    END IF;$$);
  definition := replace(definition,
    $$IF v_item_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = v_item_id AND p.restaurant_id = p_restaurant_id
    ) THEN
      legacy_movements := legacy_movements || jsonb_set(
        movement, '{product_id}', to_jsonb(v_item_id::text), true
      );
    END IF;$$,
    $$IF v_item_id IS NOT NULL THEN
      legacy_movements := legacy_movements || jsonb_set(
        movement, '{product_id}', 'null'::jsonb, true
      );
    END IF;$$);
  definition := replace(definition,
    $$IF v_item_id IS NULL OR EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = v_item_id AND p.restaurant_id = p_restaurant_id
    ) THEN
      CONTINUE;
    END IF;$$,
    $$IF v_item_id IS NULL THEN CONTINUE; END IF;$$);
  IF definition LIKE '%public.products%' THEN
    RAISE EXCEPTION 'No se pudo retirar la compatibilidad product de pos_sync_sale_v2';
  END IF;
  EXECUTE definition;
END;
$migration$;
