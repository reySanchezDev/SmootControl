-- Connect canonical recipe consumption and reversal to the active POS sale RPC.
BEGIN;

DO $migration$
DECLARE
  definition text;
  item_marker text := 'AND stored.sale_id = v_sale_id;';
  item_hook text := $hook$AND stored.sale_id = v_sale_id;

  IF COALESCE(p_payload -> 'void', '{}'::jsonb) = '{}'::jsonb AND
     COALESCE(p_payload -> 'sale' ->> 'status', '') <> 'voided' THEN
    PERFORM public.pos_apply_recipe_inventory_movements(
      p_restaurant_id, v_sale_id, 'sale'
    );
  END IF;$hook$;
  return_marker text := 'RETURN result;' || chr(10) || 'END;';
  return_hook text := $hook$IF COALESCE(p_payload -> 'void', '{}'::jsonb) <> '{}'::jsonb OR
     COALESCE(p_payload -> 'sale' ->> 'status', '') = 'voided' THEN
    PERFORM public.pos_reverse_recipe_inventory_movements(
      p_restaurant_id, v_sale_id
    );
  END IF;

  RETURN result;
END;$hook$;
BEGIN
  SELECT pg_get_functiondef(
    'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure
  ) INTO definition;
  IF position(item_marker IN definition) = 0 OR
     position(return_marker IN definition) = 0 THEN
    RAISE EXCEPTION 'Expected insertion points missing from canonical POS RPC';
  END IF;
  definition := replace(definition, item_marker, item_hook);
  definition := replace(definition, return_marker, return_hook);
  EXECUTE definition;
END;
$migration$;

COMMIT;
