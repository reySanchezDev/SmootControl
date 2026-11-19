-- Exposes the canonical business class without exposing source provenance.
-- This is additive and keeps old clients compatible when item_class is absent.
BEGIN;

ALTER FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  RENAME TO app_upsert_item_v2_base_20261118;

CREATE OR REPLACE FUNCTION public.app_upsert_item_v2(
  p_restaurant_id uuid,
  p_payload jsonb
) RETURNS public.items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_item public.items;
  v_class text;
  v_type text;
  v_can_sell boolean;
  v_source_kind text;
  v_source_id uuid;
BEGIN
  v_class := NULLIF(btrim(p_payload->>'item_class'), '');
  v_type := COALESCE(NULLIF(p_payload->>'item_type', ''), 'non_inventory');
  v_can_sell := COALESCE((p_payload->>'can_sell')::boolean, false);

  IF v_class IS NOT NULL AND v_class NOT IN (
    'sale_product', 'raw_material', 'packaging', 'service'
  ) THEN
    RAISE EXCEPTION 'item_class_invalid' USING ERRCODE = '22023';
  END IF;
  IF v_class = 'service' AND v_type <> 'service' THEN
    RAISE EXCEPTION 'service_requires_service_type' USING ERRCODE = '22023';
  END IF;
  IF v_class IN ('packaging', 'raw_material') AND v_can_sell THEN
    RAISE EXCEPTION 'non_sellable_item_class' USING ERRCODE = '22023';
  END IF;
  IF v_class = 'sale_product' AND v_type = 'service' THEN
    RAISE EXCEPTION 'sale_product_cannot_be_service' USING ERRCODE = '22023';
  END IF;

  -- The previous implementation remains the compatibility writer for all
  -- fields. Its result is normalized below in this same transaction.
  v_item := public.app_upsert_item_v2_base_20261118(
    p_restaurant_id,
    p_payload
  );

  IF v_class IS NULL THEN
    RETURN v_item;
  END IF;

  IF v_class = 'service' THEN
    v_source_kind := 'native';
    v_source_id := NULL;
  ELSIF v_class = 'packaging' THEN
    v_source_kind := 'packaging';
    v_source_id := v_item.id;
  ELSE
    v_source_kind := 'product';
    v_source_id := v_item.id;
  END IF;

  UPDATE public.items
  SET item_class = v_class,
      source_kind = v_source_kind,
      source_id = v_source_id,
      can_sell = CASE
        WHEN v_class IN ('packaging', 'raw_material') THEN false
        ELSE can_sell
      END,
      visible_in_pos = CASE
        WHEN v_class <> 'sale_product' THEN false
        ELSE visible_in_pos
      END,
      uses_recipe = CASE
        WHEN v_class IN ('packaging', 'service') THEN false
        ELSE uses_recipe
      END,
      updated_at = now()
  WHERE id = v_item.id AND restaurant_id = p_restaurant_id
  RETURNING * INTO v_item;

  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_item;
END;
$$;

REVOKE ALL ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  TO authenticated;

COMMIT;
