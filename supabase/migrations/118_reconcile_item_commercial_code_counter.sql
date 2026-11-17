-- Keep automatic commercial-code allocation monotonic after historical imports.
BEGIN;

INSERT INTO item_core_internal.item_commercial_code_counters(restaurant_id, next_value)
SELECT restaurant_id, COALESCE(MAX(commercial_code), 0) + 1
FROM public.items
GROUP BY restaurant_id
ON CONFLICT (restaurant_id) DO UPDATE
SET next_value = GREATEST(
  item_core_internal.item_commercial_code_counters.next_value,
  EXCLUDED.next_value
);

DO $migration$
DECLARE
  definition text;
  needle text := 'PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);';
  replacement text := needle || E'\n  INSERT INTO item_core_internal.item_commercial_code_counters(restaurant_id, next_value)\n'
    || E'  SELECT p_restaurant_id, COALESCE(MAX(commercial_code), 0) + 1\n'
    || E'  FROM public.items WHERE restaurant_id = p_restaurant_id\n'
    || E'  ON CONFLICT (restaurant_id) DO UPDATE SET next_value = GREATEST(\n'
    || E'    item_core_internal.item_commercial_code_counters.next_value,\n'
    || E'    EXCLUDED.next_value);';
BEGIN
  SELECT pg_get_functiondef('public.app_upsert_item_v2(uuid,jsonb)'::regprocedure)
    INTO definition;
  IF position(needle IN definition) = 0 THEN
    RAISE EXCEPTION 'No se encontro el punto de reconciliacion del codigo comercial.';
  END IF;
  definition := replace(definition, needle, replacement);
  EXECUTE definition;
END;
$migration$;

COMMIT;
