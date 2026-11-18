-- Only tests revision handshake. The actual F1 item writer and JWT roles
-- have separate F1.1 tests, and MUST be retested on full F2 cutover.
-- Loaded after disposable POS fixture + catalog export draft.
CREATE OR REPLACE FUNCTION public.app_upsert_item(
  p_restaurant_id uuid,p_payload jsonb
) RETURNS public.items LANGUAGE plpgsql SECURITY DEFINER
SET search_path=public,pg_temp
AS $$
DECLARE
  v_item public.items;
BEGIN
  IF NOT public.app_item_has_write_access(
    p_restaurant_id,'articulos.gestionar'
  ) THEN
    RAISE EXCEPTION 'item_write_not_authorized' USING ERRCODE='42501';
  END IF;
  IF p_payload->>'name'='FORCE_ERROR' THEN
    RAISE EXCEPTION 'fixture_upsert_failed' USING ERRCODE='23514';
  END IF;
  UPDATE public.items SET name=p_payload->>'name'
  WHERE id=(p_payload->>'id')::uuid
    AND restaurant_id=p_restaurant_id
  RETURNING * INTO v_item;
  IF v_item.id IS NULL THEN
    RAISE EXCEPTION 'fixture_item_missing' USING ERRCODE='23503';
  END IF;
  RETURN v_item;
END;
$$;

INSERT INTO public.item_catalog_revisions(restaurant_id)
VALUES('00000000-0000-0000-0000-000000000001');
SELECT set_config('app.can_write_inventory','true',true);
