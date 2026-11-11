-- KIVO ITEM MASTER V2 / E1-E2 ADDITIVE MIGRATION
-- This migration is independent of frozen 088. It performs no backfill,
-- creates no legacy bridge, and does not alter sales, POS or Drift queues.
BEGIN;

CREATE SCHEMA IF NOT EXISTS item_core_internal;

CREATE TABLE public.items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  code text NOT NULL CHECK (length(btrim(code)) BETWEEN 1 AND 64),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 250),
  item_type text NOT NULL CHECK (item_type IN ('inventory','non_inventory','service')),
  base_unit_id uuid NOT NULL REFERENCES public.measurement_units(id),
  base_unit_cost numeric(18,6) NOT NULL DEFAULT 0 CHECK (base_unit_cost >= 0),
  base_unit_price numeric(18,4) NOT NULL DEFAULT 0 CHECK (base_unit_price >= 0),
  can_sell boolean NOT NULL DEFAULT false,
  can_purchase boolean NOT NULL DEFAULT false,
  visible_in_pos boolean NOT NULL DEFAULT false,
  uses_recipe boolean NOT NULL DEFAULT false,
  send_to_kitchen boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT items_pos_requires_sellable CHECK (NOT visible_in_pos OR can_sell),
  CONSTRAINT items_recipe_nonservice CHECK (NOT uses_recipe OR item_type <> 'service'),
  CONSTRAINT items_tenant_id_unique UNIQUE (restaurant_id, id)
);
CREATE UNIQUE INDEX items_tenant_code_ci_uidx
  ON public.items (restaurant_id, lower(btrim(code)));
CREATE INDEX items_active_type_idx ON public.items (restaurant_id, item_type, is_active);

CREATE TABLE public.item_units (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  item_id uuid NOT NULL,
  unit_id uuid NOT NULL REFERENCES public.measurement_units(id),
  quantity_in_base numeric(18,8) NOT NULL CHECK (quantity_in_base > 0),
  is_purchase boolean NOT NULL DEFAULT false,
  is_sale boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  PRIMARY KEY (restaurant_id, item_id, unit_id),
  FOREIGN KEY (restaurant_id, item_id) REFERENCES public.items(restaurant_id, id)
    ON DELETE CASCADE
);
CREATE UNIQUE INDEX item_one_purchase_unit_idx
  ON public.item_units (restaurant_id, item_id) WHERE is_purchase AND is_active;
CREATE UNIQUE INDEX item_one_sale_unit_idx
  ON public.item_units (restaurant_id, item_id) WHERE is_sale AND is_active;

CREATE TABLE public.item_classifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  code text NOT NULL CHECK (length(btrim(code)) BETWEEN 1 AND 64),
  name text NOT NULL CHECK (length(btrim(name)) > 0),
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (restaurant_id, id)
);
CREATE UNIQUE INDEX item_classifications_code_ci_uq
  ON public.item_classifications (restaurant_id, lower(btrim(code)));

CREATE TABLE public.item_classification_links (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  item_id uuid NOT NULL,
  classification_id uuid NOT NULL,
  PRIMARY KEY (restaurant_id, item_id, classification_id),
  FOREIGN KEY (restaurant_id, item_id) REFERENCES public.items(restaurant_id, id)
    ON DELETE CASCADE,
  FOREIGN KEY (restaurant_id, classification_id)
    REFERENCES public.item_classifications(restaurant_id, id)
    ON DELETE CASCADE
);

CREATE TABLE public.item_consumption_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  source_item_id uuid,
  consumed_item_id uuid NOT NULL,
  sales_type_id uuid,
  scope text NOT NULL CHECK (scope IN ('per_sale_line', 'per_order')),
  quantity numeric(18,6) NOT NULL CHECK (quantity > 0),
  unit_id uuid NOT NULL REFERENCES public.measurement_units(id),
  priority integer NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (restaurant_id, id),
  FOREIGN KEY (restaurant_id, source_item_id) REFERENCES public.items(restaurant_id, id),
  FOREIGN KEY (restaurant_id, consumed_item_id)
    REFERENCES public.items(restaurant_id, id),
  CONSTRAINT consumption_line_has_source CHECK
    (scope <> 'per_sale_line' OR source_item_id IS NOT NULL),
  CONSTRAINT consumption_no_self_link CHECK
    (source_item_id IS NULL OR source_item_id <> consumed_item_id)
);
CREATE INDEX item_consumption_rules_lookup_idx ON public.item_consumption_rules
  (restaurant_id, sales_type_id, source_item_id, scope, priority)
  WHERE is_active;

CREATE TABLE public.item_catalog_revisions (
  restaurant_id uuid PRIMARY KEY REFERENCES public.restaurants(id),
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  snapshot_id uuid NOT NULL DEFAULT gen_random_uuid(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_classifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_classification_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_consumption_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_catalog_revisions ENABLE ROW LEVEL SECURITY;

CREATE POLICY items_tenant_read ON public.items FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_units_tenant_read ON public.item_units FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_classifications_tenant_read
  ON public.item_classifications FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_classification_links_tenant_read
  ON public.item_classification_links FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_consumption_rules_tenant_read
  ON public.item_consumption_rules FOR SELECT TO authenticated
  USING (restaurant_id = public.current_restaurant_id());

REVOKE ALL ON public.items, public.item_units, public.item_classifications,
  public.item_classification_links, public.item_consumption_rules,
  public.item_catalog_revisions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.items, public.item_units, public.item_classifications,
  public.item_classification_links, public.item_consumption_rules TO authenticated;

CREATE OR REPLACE FUNCTION item_core_internal.bump_item_catalog_revision(
  p_restaurant_id uuid
) RETURNS TABLE (revision bigint, snapshot_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE public.item_catalog_revisions
  SET revision = revision + 1, snapshot_id = gen_random_uuid(), updated_at = now()
  WHERE restaurant_id = p_restaurant_id
  RETURNING item_catalog_revisions.revision, item_catalog_revisions.snapshot_id
  INTO revision, snapshot_id;
  IF revision IS NULL THEN
    INSERT INTO public.item_catalog_revisions(restaurant_id)
    VALUES (p_restaurant_id)
    RETURNING item_catalog_revisions.revision, item_catalog_revisions.snapshot_id
    INTO revision, snapshot_id;
  END IF;
  RETURN NEXT;
END;
$$;
REVOKE ALL ON FUNCTION item_core_internal.bump_item_catalog_revision(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.pos_pull_item_catalog_v2(
  p_restaurant_id uuid, p_device_id uuid, p_device_secret text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE v_revision bigint; v_snapshot_id uuid;
BEGIN
  PERFORM public.assert_pos_device(p_restaurant_id, p_device_id, p_device_secret);
  SELECT revision, snapshot_id INTO v_revision, v_snapshot_id
  FROM public.item_catalog_revisions WHERE restaurant_id = p_restaurant_id FOR SHARE;
  IF v_revision IS NULL THEN RAISE EXCEPTION 'catalog_revision_not_initialized'; END IF;
  RETURN jsonb_build_object(
    'contract_version', 2, 'restaurant_id', p_restaurant_id,
    'snapshot_complete', true, 'snapshot_id', v_snapshot_id, 'revision', v_revision,
    'items', COALESCE((SELECT jsonb_agg(to_jsonb(i) ORDER BY i.code, i.id)
      FROM public.items i WHERE i.restaurant_id = p_restaurant_id), '[]'::jsonb),
    'item_units', COALESCE((SELECT jsonb_agg(to_jsonb(u) ORDER BY u.item_id, u.unit_id)
      FROM public.item_units u WHERE u.restaurant_id = p_restaurant_id AND u.is_active), '[]'::jsonb),
    'item_classifications', COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.code, c.id)
      FROM public.item_classifications c WHERE c.restaurant_id = p_restaurant_id), '[]'::jsonb),
    'item_classification_links', COALESCE((SELECT jsonb_agg(to_jsonb(l)
      ORDER BY l.item_id, l.classification_id) FROM public.item_classification_links l
      WHERE l.restaurant_id = p_restaurant_id), '[]'::jsonb),
    'consumption_rules', COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.id)
      FROM public.item_consumption_rules r WHERE r.restaurant_id = p_restaurant_id
      AND r.is_active), '[]'::jsonb));
END;
$$;
REVOKE ALL ON FUNCTION public.pos_pull_item_catalog_v2(uuid, uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pos_pull_item_catalog_v2(uuid, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION item_core_internal.assert_catalog_write(
  p_restaurant_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_same_restaurant(p_restaurant_id)
     OR NOT public.app_can_manage_packaging_catalog(
       p_restaurant_id, 'productos.gestionar') THEN
    RAISE EXCEPTION 'item_catalog_write_not_authorized' USING ERRCODE = '42501';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION item_core_internal.assert_catalog_write(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.app_upsert_item_v2(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS public.items LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE v_item public.items;
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);
  INSERT INTO public.items (
    id, restaurant_id, code, name, item_type, base_unit_id, base_unit_cost,
    base_unit_price, can_sell, can_purchase, visible_in_pos, uses_recipe,
    send_to_kitchen, is_active, updated_at
  ) VALUES (
    COALESCE((p_payload->>'id')::uuid, gen_random_uuid()), p_restaurant_id,
    btrim(p_payload->>'code'), btrim(p_payload->>'name'), p_payload->>'item_type',
    (p_payload->>'base_unit_id')::uuid, COALESCE((p_payload->>'base_unit_cost')::numeric, 0),
    COALESCE((p_payload->>'base_unit_price')::numeric, 0),
    COALESCE((p_payload->>'can_sell')::boolean, false),
    COALESCE((p_payload->>'can_purchase')::boolean, false),
    COALESCE((p_payload->>'visible_in_pos')::boolean, false),
    COALESCE((p_payload->>'uses_recipe')::boolean, false),
    COALESCE((p_payload->>'send_to_kitchen')::boolean, false),
    COALESCE((p_payload->>'is_active')::boolean, true), now()
  ) ON CONFLICT (id) DO UPDATE SET
    code = EXCLUDED.code, name = EXCLUDED.name, item_type = EXCLUDED.item_type,
    base_unit_id = EXCLUDED.base_unit_id, base_unit_cost = EXCLUDED.base_unit_cost,
    base_unit_price = EXCLUDED.base_unit_price, can_sell = EXCLUDED.can_sell,
    can_purchase = EXCLUDED.can_purchase, visible_in_pos = EXCLUDED.visible_in_pos,
    uses_recipe = EXCLUDED.uses_recipe, send_to_kitchen = EXCLUDED.send_to_kitchen,
    is_active = EXCLUDED.is_active, updated_at = now()
  WHERE public.items.restaurant_id = p_restaurant_id
  RETURNING * INTO v_item;
  IF v_item.id IS NULL THEN RAISE EXCEPTION 'item_not_in_restaurant'; END IF;
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_item;
END;
$$;
REVOKE ALL ON FUNCTION public.app_upsert_item_v2(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_v2(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_upsert_item_unit_v2(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS public.item_units LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE v_unit public.item_units;
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);
  INSERT INTO public.item_units(
    restaurant_id, item_id, unit_id, quantity_in_base, is_purchase, is_sale, is_active
  ) VALUES (
    p_restaurant_id, (p_payload->>'item_id')::uuid, (p_payload->>'unit_id')::uuid,
    (p_payload->>'quantity_in_base')::numeric,
    COALESCE((p_payload->>'is_purchase')::boolean, false),
    COALESCE((p_payload->>'is_sale')::boolean, false),
    COALESCE((p_payload->>'is_active')::boolean, true)
  ) ON CONFLICT (restaurant_id, item_id, unit_id) DO UPDATE SET
    quantity_in_base = EXCLUDED.quantity_in_base, is_purchase = EXCLUDED.is_purchase,
    is_sale = EXCLUDED.is_sale, is_active = EXCLUDED.is_active
  RETURNING * INTO v_unit;
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_unit;
END;
$$;
REVOKE ALL ON FUNCTION public.app_upsert_item_unit_v2(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_unit_v2(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_upsert_item_classification_v2(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS public.item_classifications LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE v_row public.item_classifications;
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);
  INSERT INTO public.item_classifications(id, restaurant_id, code, name, is_active)
  VALUES (COALESCE((p_payload->>'id')::uuid, gen_random_uuid()), p_restaurant_id,
    btrim(p_payload->>'code'), btrim(p_payload->>'name'),
    COALESCE((p_payload->>'is_active')::boolean, true))
  ON CONFLICT (id) DO UPDATE SET code=EXCLUDED.code, name=EXCLUDED.name,
    is_active=EXCLUDED.is_active WHERE item_classifications.restaurant_id=p_restaurant_id
  RETURNING * INTO v_row;
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_row;
END;
$$;
REVOKE ALL ON FUNCTION public.app_upsert_item_classification_v2(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_classification_v2(uuid, jsonb)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.app_set_item_classification_v2(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);
  IF COALESCE((p_payload->>'enabled')::boolean, true) THEN
    INSERT INTO public.item_classification_links(restaurant_id, item_id, classification_id)
    VALUES (p_restaurant_id, (p_payload->>'item_id')::uuid,
      (p_payload->>'classification_id')::uuid) ON CONFLICT DO NOTHING;
  ELSE
    DELETE FROM public.item_classification_links
    WHERE restaurant_id=p_restaurant_id AND item_id=(p_payload->>'item_id')::uuid
      AND classification_id=(p_payload->>'classification_id')::uuid;
  END IF;
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
END;
$$;
REVOKE ALL ON FUNCTION public.app_set_item_classification_v2(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_set_item_classification_v2(uuid, jsonb)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.app_upsert_item_consumption_rule_v2(
  p_restaurant_id uuid, p_payload jsonb
) RETURNS public.item_consumption_rules LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE v_row public.item_consumption_rules;
BEGIN
  PERFORM item_core_internal.assert_catalog_write(p_restaurant_id);
  INSERT INTO public.item_consumption_rules(
    id, restaurant_id, source_item_id, consumed_item_id, sales_type_id, scope,
    quantity, unit_id, priority, is_active, updated_at
  ) VALUES (
    COALESCE((p_payload->>'id')::uuid, gen_random_uuid()), p_restaurant_id,
    (p_payload->>'source_item_id')::uuid, (p_payload->>'consumed_item_id')::uuid,
    (p_payload->>'sales_type_id')::uuid, p_payload->>'scope',
    (p_payload->>'quantity')::numeric, (p_payload->>'unit_id')::uuid,
    COALESCE((p_payload->>'priority')::integer, 100),
    COALESCE((p_payload->>'is_active')::boolean, true), now()
  ) ON CONFLICT (id) DO UPDATE SET source_item_id=EXCLUDED.source_item_id,
    consumed_item_id=EXCLUDED.consumed_item_id, sales_type_id=EXCLUDED.sales_type_id,
    scope=EXCLUDED.scope, quantity=EXCLUDED.quantity, unit_id=EXCLUDED.unit_id,
    priority=EXCLUDED.priority, is_active=EXCLUDED.is_active, updated_at=now()
  WHERE item_consumption_rules.restaurant_id=p_restaurant_id
  RETURNING * INTO v_row;
  PERFORM item_core_internal.bump_item_catalog_revision(p_restaurant_id);
  RETURN v_row;
END;
$$;
REVOKE ALL ON FUNCTION public.app_upsert_item_consumption_rule_v2(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_upsert_item_consumption_rule_v2(uuid, jsonb)
  TO authenticated;

COMMIT;
