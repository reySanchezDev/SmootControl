-- Add a tenant-scoped, user-facing integer code without changing technical IDs.
BEGIN;

ALTER TABLE public.items
  ADD COLUMN IF NOT EXISTS commercial_code bigint;

CREATE TABLE IF NOT EXISTS item_core_internal.item_commercial_code_counters (
  restaurant_id uuid PRIMARY KEY REFERENCES public.restaurants(id) ON DELETE CASCADE,
  next_value bigint NOT NULL CHECK (next_value > 0)
);

REVOKE ALL ON item_core_internal.item_commercial_code_counters FROM PUBLIC, anon,
  authenticated;

WITH numbered AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY restaurant_id ORDER BY created_at, id
         )::bigint AS assigned_code
  FROM public.items
)
UPDATE public.items AS i
SET commercial_code = numbered.assigned_code
FROM numbered
WHERE i.id = numbered.id
  AND i.commercial_code IS NULL;

INSERT INTO item_core_internal.item_commercial_code_counters(
  restaurant_id, next_value
)
SELECT r.id, COALESCE(MAX(i.commercial_code), 0) + 1
FROM public.restaurants r
LEFT JOIN public.items i ON i.restaurant_id = r.id
GROUP BY r.id
ON CONFLICT (restaurant_id) DO UPDATE
SET next_value = GREATEST(
  item_core_internal.item_commercial_code_counters.next_value,
  EXCLUDED.next_value
);

ALTER TABLE public.items
  ALTER COLUMN commercial_code SET NOT NULL,
  ADD CONSTRAINT items_commercial_code_positive
    CHECK (commercial_code > 0);

CREATE UNIQUE INDEX IF NOT EXISTS items_tenant_commercial_code_unique
  ON public.items (restaurant_id, commercial_code);

CREATE OR REPLACE FUNCTION public.app_upsert_item_v2(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS public.items LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_item public.items;
  v_requested integer;
  v_found integer;
  v_id uuid;
  v_code text;
  v_commercial_code bigint;
  v_requested_code bigint;
  v_item_class text;
  v_source_kind text;
  v_source_id uuid;
  v_category_id uuid;
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);
  v_id := NULLIF(p_payload->>'id', '')::uuid;
  v_category_id := NULLIF(p_payload->>'category_id', '')::uuid;

  IF v_category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.product_categories
    WHERE id = v_category_id
      AND restaurant_id = p_restaurant_id
      AND is_active
  ) THEN
    RAISE EXCEPTION 'item_category_not_found_or_inactive'
      USING ERRCODE = '23503';
  END IF;

  IF v_id IS NULL THEN
    v_id := gen_random_uuid();
    v_code := 'ART-' || nextval(
      'item_core_internal.item_business_code_seq'::regclass
    )::text;
    SELECT next_value INTO v_commercial_code
    FROM item_core_internal.item_commercial_code_counters
    WHERE restaurant_id = p_restaurant_id
    FOR UPDATE;
    IF NOT FOUND THEN
      INSERT INTO item_core_internal.item_commercial_code_counters(
        restaurant_id, next_value
      ) VALUES (p_restaurant_id, 2)
      RETURNING next_value - 1 INTO v_commercial_code;
    ELSE
      UPDATE item_core_internal.item_commercial_code_counters
      SET next_value = next_value + 1
      WHERE restaurant_id = p_restaurant_id;
    END IF;
    IF p_payload->>'item_type' = 'service' THEN
      v_item_class := 'service';
      v_source_kind := 'native';
      v_source_id := NULL;
    ELSE
      v_item_class := 'sale_product';
      v_source_kind := 'product';
      v_source_id := v_id;
    END IF;
  ELSE
    SELECT code, commercial_code, item_class, source_kind, source_id
      INTO v_code, v_commercial_code, v_item_class, v_source_kind, v_source_id
    FROM public.items
    WHERE id = v_id AND restaurant_id = p_restaurant_id
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'item_not_in_restaurant' USING ERRCODE = '42501';
    END IF;
  END IF;

  IF p_payload ? 'commercial_code' THEN
    v_requested_code := NULLIF(p_payload->>'commercial_code', '')::bigint;
    IF v_requested_code IS NULL OR v_requested_code <= 0 THEN
      RAISE EXCEPTION 'item_commercial_code_invalid' USING ERRCODE = '22023';
    END IF;
    v_commercial_code := v_requested_code;
    INSERT INTO item_core_internal.item_commercial_code_counters(
      restaurant_id, next_value
    ) VALUES (p_restaurant_id, v_commercial_code + 1)
    ON CONFLICT (restaurant_id) DO UPDATE
    SET next_value = GREATEST(
      item_core_internal.item_commercial_code_counters.next_value,
      EXCLUDED.next_value
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.items
    WHERE restaurant_id = p_restaurant_id
      AND commercial_code = v_commercial_code
      AND id <> v_id
  ) THEN
    RAISE EXCEPTION 'item_commercial_code_duplicate' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.items (
    id, restaurant_id, code, commercial_code, name, item_type, item_class,
    source_kind, source_id, category_id, base_unit_id, base_unit_cost,
    base_unit_price, can_sell, can_purchase, visible_in_pos, uses_recipe,
    send_to_kitchen, is_active, updated_at
  ) VALUES (
    v_id, p_restaurant_id, v_code, v_commercial_code,
    btrim(p_payload->>'name'), p_payload->>'item_type', v_item_class,
    v_source_kind, v_source_id, v_category_id,
    (p_payload->>'base_unit_id')::uuid,
    COALESCE((p_payload->>'base_unit_cost')::numeric, 0),
    COALESCE((p_payload->>'base_unit_price')::numeric, 0),
    COALESCE((p_payload->>'can_sell')::boolean, false),
    COALESCE((p_payload->>'can_purchase')::boolean, false),
    COALESCE((p_payload->>'visible_in_pos')::boolean, false),
    COALESCE((p_payload->>'uses_recipe')::boolean, false),
    COALESCE((p_payload->>'send_to_kitchen')::boolean, false),
    COALESCE((p_payload->>'is_active')::boolean, true), now()
  ) ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    commercial_code = EXCLUDED.commercial_code,
    item_type = EXCLUDED.item_type,
    category_id = EXCLUDED.category_id,
    base_unit_id = EXCLUDED.base_unit_id,
    base_unit_cost = EXCLUDED.base_unit_cost,
    base_unit_price = EXCLUDED.base_unit_price,
    can_sell = EXCLUDED.can_sell,
    can_purchase = EXCLUDED.can_purchase,
    visible_in_pos = EXCLUDED.visible_in_pos,
    uses_recipe = EXCLUDED.uses_recipe,
    send_to_kitchen = EXCLUDED.send_to_kitchen,
    is_active = EXCLUDED.is_active,
    updated_at = now()
  WHERE public.items.restaurant_id = p_restaurant_id
  RETURNING * INTO v_item;

  IF v_item.id IS NULL THEN
    RAISE EXCEPTION 'item_not_in_restaurant';
  END IF;

  IF p_payload ? 'classification_ids' THEN
    IF jsonb_typeof(p_payload->'classification_ids') <> 'array' THEN
      RAISE EXCEPTION 'classification_ids_invalid' USING ERRCODE = '22023';
    END IF;
    SELECT count(DISTINCT value::uuid) INTO v_requested
    FROM jsonb_array_elements_text(p_payload->'classification_ids');
    SELECT count(*) INTO v_found
    FROM public.item_classifications c
    WHERE c.restaurant_id = p_restaurant_id AND c.is_active
      AND c.id IN (
        SELECT DISTINCT value::uuid
        FROM jsonb_array_elements_text(p_payload->'classification_ids')
      );
    IF v_requested <> v_found THEN
      RAISE EXCEPTION 'item_classification_not_found_or_inactive'
        USING ERRCODE = '23503';
    END IF;
    DELETE FROM public.item_classification_links
    WHERE restaurant_id = p_restaurant_id AND item_id = v_item.id;
    INSERT INTO public.item_classification_links(
      restaurant_id, item_id, classification_id
    )
    SELECT p_restaurant_id, v_item.id, value::uuid
    FROM (
      SELECT DISTINCT value
      FROM jsonb_array_elements_text(p_payload->'classification_ids')
    ) requested;
  END IF;

  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_item;
END;
$$;

REVOKE ALL ON FUNCTION public.app_upsert_item_v2(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_v2(uuid, jsonb) TO authenticated;

COMMIT;
