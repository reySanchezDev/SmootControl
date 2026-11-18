-- Do not let the retired sale core consume canonical inventory movements.
BEGIN;

DO $migration$
DECLARE
  definition text;
  needle text := $$normalized := jsonb_set(
    normalized, '{inventory_movements}', legacy_movements, true
  );$$;
  replacement text := $$normalized := jsonb_set(
    normalized, '{inventory_movements}', '[]'::jsonb, true
  );$$;
BEGIN
  SELECT pg_get_functiondef(
    'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure
  ) INTO definition;
  IF position(needle IN definition) = 0 THEN
    RAISE EXCEPTION 'No se encontro el limite de movimientos canonicos POS.';
  END IF;
  EXECUTE replace(definition, needle, replacement);
END;
$migration$;

COMMIT;
