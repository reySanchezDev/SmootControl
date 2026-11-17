-- Fix canonical POS sale reversal identifier parsing.
-- Depends on 102_pos_item_sale_inventory_contract.sql.
DO $migration$
DECLARE
  current_definition text;
  fixed_definition text;
  faulty_expression constant text := $$reversal_id := 'void:' || movement ->> 'id';$$;
  corrected_expression constant text := $$reversal_id := 'void:' || (movement ->> 'id');$$;
BEGIN
  SELECT pg_get_functiondef(
    'public.pos_sync_sale_v2(uuid,uuid,text,jsonb)'::regprocedure
  ) INTO current_definition;

  IF current_definition IS NULL THEN
    RAISE EXCEPTION 'Falta pos_sync_sale_v2; aplicar migración 102 primero';
  END IF;

  IF position(faulty_expression IN current_definition) = 0 THEN
    IF position(corrected_expression IN current_definition) > 0 THEN
      RETURN;
    END IF;
    RAISE EXCEPTION 'No se encontró la expresión esperada de reversión POS';
  END IF;

  fixed_definition := replace(
    current_definition,
    faulty_expression,
    corrected_expression
  );
  EXECUTE fixed_definition;
END;
$migration$;

COMMENT ON FUNCTION public.pos_sync_sale_v2(uuid,uuid,text,jsonb)
  IS 'POS canonical item sale synchronization with idempotent inventory reversal';
