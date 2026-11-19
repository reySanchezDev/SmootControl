-- Keeps the technical inventory flag derived from the selected item type.
BEGIN;

DO $migration$
DECLARE
  definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.app_upsert_item_v2(uuid,jsonb)'::regprocedure
  ) INTO definition;
  IF position('name, item_type, item_class,' IN definition) = 0 THEN
    RAISE EXCEPTION 'No se encontró el contrato de inserción de items';
  END IF;
  definition := replace(
    definition,
    'name, item_type, item_class,',
    'name, item_type, item_class, tracks_inventory,'
  );
  definition := replace(
    definition,
    'v_item_type, v_item_class, v_source_kind,',
    'v_item_type, v_item_class, v_item_type = ''inventory'', v_source_kind,'
  );
  definition := replace(
    definition,
    'item_type = EXCLUDED.item_type, category_id = EXCLUDED.category_id,',
    'item_type = EXCLUDED.item_type, tracks_inventory = EXCLUDED.tracks_inventory, '
      'category_id = EXCLUDED.category_id,'
  );
  IF position('tracks_inventory' IN definition) = 0 THEN
    RAISE EXCEPTION 'No se pudo agregar tracks_inventory al RPC';
  END IF;
  EXECUTE definition;
END;
$migration$;

COMMIT;
