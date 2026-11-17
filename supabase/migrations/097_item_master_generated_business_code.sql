-- Generate canonical article codes in PostgreSQL; clients never provide them.
-- Migration 088 remains frozen and is not executed by this change.
BEGIN;

CREATE SEQUENCE IF NOT EXISTS item_core_internal.item_business_code_seq
  AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;

REVOKE ALL ON SEQUENCE item_core_internal.item_business_code_seq
  FROM PUBLIC, anon, authenticated;

SELECT setval(
  'item_core_internal.item_business_code_seq'::regclass,
  GREATEST(
    1,
    COALESCE(
      MAX((substring(upper(btrim(code)) FROM '^ART-([0-9]+))::bigint),
      0
    ) + 1
  ),
  false
)
FROM public.items
WHERE upper(btrim(code)) ~ '^ART-[0-9]{1,15}

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
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);

  v_id := NULLIF(p_payload->>'id', '')::uuid;
  IF v_id IS NULL THEN
    v_id := gen_random_uuid();
    v_code := 'ART-' || nextval('item_core_internal.item_business_code_seq'::regclass)::text;
  ELSE
    SELECT code INTO v_code FROM public.items
    WHERE id = v_id AND restaurant_id = p_restaurant_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'item_not_in_restaurant' USING ERRCODE='42501';
    END IF;
  END IF;

  INSERT INTO public.items (
    id, restaurant_id, code, name, item_type, base_unit_id, base_unit_cost,
    base_unit_price, can_sell, can_purchase, visible_in_pos, uses_recipe,
    send_to_kitchen, is_active, updated_at
  ) VALUES (
    v_id, p_restaurant_id, v_code,
    btrim(p_payload->>'name'), p_payload->>'item_type',
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
    item_type = EXCLUDED.item_type,
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
      RAISE EXCEPTION 'classification_ids_invalid' USING ERRCODE='22023';
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
        USING ERRCODE='23503';
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

REVOKE ALL ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  TO authenticated;

COMMIT;
))::bigint),
      0
    ) + 1
  ),
  false
)
FROM public.items
WHERE code ~ '^ART-[0-9]{1,15}$';

CREATE OR REPLACE FUNCTION public.app_upsert_item_v2(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS public.items LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_item public.items;
  v_requested integer;
  v_found integer;
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);

  INSERT INTO public.items (
    id, restaurant_id, code, name, item_type, base_unit_id, base_unit_cost,
    base_unit_price, can_sell, can_purchase, visible_in_pos, uses_recipe,
    send_to_kitchen, is_active, updated_at
  ) VALUES (
    COALESCE((p_payload->>'id')::uuid, gen_random_uuid()), p_restaurant_id,
    'ART-' || nextval('item_core_internal.item_business_code_seq'::regclass)::text,
    btrim(p_payload->>'name'), p_payload->>'item_type',
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
    item_type = EXCLUDED.item_type,
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
      RAISE EXCEPTION 'classification_ids_invalid' USING ERRCODE='22023';
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
        USING ERRCODE='23503';
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

REVOKE ALL ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  TO authenticated;

COMMIT;
;

CREATE OR REPLACE FUNCTION public.app_upsert_item_v2(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS public.items LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_item public.items;
  v_requested integer;
  v_found integer;
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);

  INSERT INTO public.items (
    id, restaurant_id, code, name, item_type, base_unit_id, base_unit_cost,
    base_unit_price, can_sell, can_purchase, visible_in_pos, uses_recipe,
    send_to_kitchen, is_active, updated_at
  ) VALUES (
    COALESCE((p_payload->>'id')::uuid, gen_random_uuid()), p_restaurant_id,
    'ART-' || nextval('item_core_internal.item_business_code_seq'::regclass)::text,
    btrim(p_payload->>'name'), p_payload->>'item_type',
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
    item_type = EXCLUDED.item_type,
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
      RAISE EXCEPTION 'classification_ids_invalid' USING ERRCODE='22023';
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
        USING ERRCODE='23503';
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

REVOKE ALL ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  TO authenticated;

COMMIT;
))::bigint),
      0
    ) + 1
  ),
  false
)
FROM public.items
WHERE code ~ '^ART-[0-9]{1,15}$';

CREATE OR REPLACE FUNCTION public.app_upsert_item_v2(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS public.items LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_item public.items;
  v_requested integer;
  v_found integer;
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);

  INSERT INTO public.items (
    id, restaurant_id, code, name, item_type, base_unit_id, base_unit_cost,
    base_unit_price, can_sell, can_purchase, visible_in_pos, uses_recipe,
    send_to_kitchen, is_active, updated_at
  ) VALUES (
    COALESCE((p_payload->>'id')::uuid, gen_random_uuid()), p_restaurant_id,
    'ART-' || nextval('item_core_internal.item_business_code_seq'::regclass)::text,
    btrim(p_payload->>'name'), p_payload->>'item_type',
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
    item_type = EXCLUDED.item_type,
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
      RAISE EXCEPTION 'classification_ids_invalid' USING ERRCODE='22023';
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
        USING ERRCODE='23503';
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

REVOKE ALL ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_v2(uuid, jsonb)
  TO authenticated;

COMMIT;
