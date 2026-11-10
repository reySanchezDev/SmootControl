-- Item master foundation (Phase 1: database ONLY).
-- Business Central-inspired item type is separate from business classification.
-- Legacy product / packaging IDs and their inventory, recipe and sales FKs remain.
-- New item master is a persisted, tenant-scoped identity, NOT a UNION view.
-- Legacy source tables stay the write entry points until a separately tested
-- POS/API cutover; triggers mirror changes into the item master.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.products p
    JOIN public.packaging_items k ON k.id = p.id
  ) THEN
    RAISE EXCEPTION 'Item master migration: source UUID collision';
  END IF;
END;
$$;

CREATE TABLE public.items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  code text NOT NULL,
  name text NOT NULL,
  item_type text NOT NULL CHECK (item_type IN (
    'inventory', 'non_inventory', 'service'
  )),
  item_class text NOT NULL CHECK (item_class IN (
    'sale_product', 'raw_material', 'packaging', 'service'
  )),
  source_kind text NOT NULL CHECK (source_kind IN (
    'product', 'packaging', 'native'
  )),
  source_id uuid,
  category_id uuid REFERENCES public.product_categories(id),
  unit_cost numeric(15,4) NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
  unit_price numeric(15,4) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
  is_sellable boolean NOT NULL DEFAULT false,
  tracks_inventory boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT items_source_contract CHECK (
    (source_kind = 'native' AND source_id IS NULL)
    OR (source_kind IN ('product', 'packaging') AND source_id = id)
  ),
  CONSTRAINT items_type_inventory_contract CHECK (
    item_type = 'inventory' OR NOT tracks_inventory
  ),
  CONSTRAINT items_class_contract CHECK (
    (item_class = 'packaging' AND source_kind = 'packaging' AND NOT is_sellable)
    OR (item_class = 'raw_material' AND source_kind = 'product' AND NOT is_sellable)
    OR (item_class = 'sale_product' AND source_kind = 'product')
    OR (item_class = 'service' AND source_kind = 'native'
        AND item_type = 'service' AND NOT tracks_inventory)
  ),
  CONSTRAINT items_source_type_contract CHECK (
    (source_kind = 'packaging' AND item_type <> 'service')
    OR (source_kind = 'product' AND item_type <> 'service')
    OR (source_kind = 'native' AND item_type = 'service')
  ),
  CONSTRAINT items_code_not_blank CHECK (length(btrim(code)) > 0),
  CONSTRAINT items_name_not_blank CHECK (length(btrim(name)) > 0),
  CONSTRAINT items_restaurant_id_unique UNIQUE (restaurant_id, id)
);

CREATE UNIQUE INDEX items_tenant_code_unique
  ON public.items (restaurant_id, lower(btrim(code)));
CREATE UNIQUE INDEX items_tenant_source_unique
  ON public.items (restaurant_id, source_kind, source_id)
  WHERE source_id IS NOT NULL;
CREATE INDEX items_restaurant_class_active_idx
  ON public.items (restaurant_id, item_class, is_active);
CREATE INDEX items_restaurant_type_idx
  ON public.items (restaurant_id, item_type);

COMMENT ON TABLE public.items IS
  'Canonical item identity and classification. Legacy product/packaging tables remain compatibility write sources during phased migration; service items are native.';
COMMENT ON COLUMN public.items.item_type IS
  'Inventory / Non-Inventory / Service concept, independent from business classification.';
COMMENT ON COLUMN public.items.item_class IS
  'Business classification: sale product, raw material, packaging, service.';
COMMENT ON COLUMN public.items.source_kind IS
  'Compatibility provenance. Legacy IDs are preserved exactly; native is service-only in phase 1.';

-- Existing code is preserved for products. Packaging has never had a code:
-- its stable prefixed UUID-derived code cannot collide with existing product
-- codes, unless an old product already used that exact value.
INSERT INTO public.items (
  id, restaurant_id, code, name, item_type, item_class,
  source_kind, source_id, category_id, unit_cost, unit_price,
  is_sellable, tracks_inventory, is_active, created_at, updated_at
)
SELECT
  p.id, p.restaurant_id, p.code, p.name,
  CASE WHEN p.tracks_inventory THEN 'inventory' ELSE 'non_inventory' END,
  CASE WHEN p.is_raw_material THEN 'raw_material' ELSE 'sale_product' END,
  'product', p.id, p.category_id, p.cost, p.price,
  NOT p.is_raw_material, p.tracks_inventory, p.is_active,
  p.created_at, p.updated_at
FROM public.products AS p;

INSERT INTO public.items (
  id, restaurant_id, code, name, item_type, item_class,
  source_kind, source_id, unit_cost, unit_price,
  is_sellable, tracks_inventory, is_active, created_at, updated_at
)
SELECT
  k.id, k.restaurant_id, 'PKG-' || k.id::text, k.name,
  CASE WHEN k.tracks_stock THEN 'inventory' ELSE 'non_inventory' END,
  'packaging', 'packaging', k.id, k.cost, 0,
  false, k.tracks_stock, k.is_active, k.created_at, k.updated_at
FROM public.packaging_items AS k;

-- Compatibility bridge: existing POS, drift and RPC callers still write the
-- legacy tables. Never duplicate or re-key inventory / ledger rows.
CREATE FUNCTION public.sync_item_master_from_legacy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.items
    WHERE id = OLD.id
      AND restaurant_id = OLD.restaurant_id
      AND source_kind = TG_ARGV[0];
    RETURN OLD;
  END IF;

  IF TG_ARGV[0] = 'product' THEN
    INSERT INTO public.items (
      id, restaurant_id, code, name, item_type, item_class,
      source_kind, source_id, category_id, unit_cost, unit_price,
      is_sellable, tracks_inventory, is_active, created_at, updated_at
    )
    VALUES (
      NEW.id, NEW.restaurant_id, NEW.code, NEW.name,
      CASE WHEN NEW.tracks_inventory THEN 'inventory' ELSE 'non_inventory' END,
      CASE WHEN NEW.is_raw_material THEN 'raw_material' ELSE 'sale_product' END,
      'product', NEW.id, NEW.category_id, NEW.cost, NEW.price,
      NOT NEW.is_raw_material, NEW.tracks_inventory, NEW.is_active,
      NEW.created_at, NEW.updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
      code = excluded.code,
      name = excluded.name,
      item_type = excluded.item_type,
      item_class = excluded.item_class,
      category_id = excluded.category_id,
      unit_cost = excluded.unit_cost,
      unit_price = excluded.unit_price,
      is_sellable = excluded.is_sellable,
      tracks_inventory = excluded.tracks_inventory,
      is_active = excluded.is_active,
      updated_at = excluded.updated_at
    WHERE public.items.restaurant_id = excluded.restaurant_id
      AND public.items.source_kind = 'product'
      AND public.items.source_id = excluded.source_id;
  ELSE
    INSERT INTO public.items (
      id, restaurant_id, code, name, item_type, item_class,
      source_kind, source_id, category_id, unit_cost, unit_price,
      is_sellable, tracks_inventory, is_active, created_at, updated_at
    )
    VALUES (
      NEW.id, NEW.restaurant_id, 'PKG-' || NEW.id::text, NEW.name,
      CASE WHEN NEW.tracks_stock THEN 'inventory' ELSE 'non_inventory' END,
      'packaging', 'packaging', NEW.id, null, NEW.cost, 0,
      false, NEW.tracks_stock, NEW.is_active, NEW.created_at, NEW.updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
      name = excluded.name,
      item_type = excluded.item_type,
      item_class = excluded.item_class,
      unit_cost = excluded.unit_cost,
      tracks_inventory = excluded.tracks_inventory,
      is_active = excluded.is_active,
      updated_at = excluded.updated_at
    WHERE public.items.restaurant_id = excluded.restaurant_id
      AND public.items.source_kind = 'packaging'
      AND public.items.source_id = excluded.source_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.items
    WHERE id = NEW.id
      AND restaurant_id = NEW.restaurant_id
      AND source_kind = TG_ARGV[0]
  ) THEN
    RAISE EXCEPTION 'Item master identity/source mismatch'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_item_master_from_legacy()
  FROM PUBLIC;

CREATE TRIGGER products_sync_item_master
AFTER INSERT OR UPDATE OR DELETE ON public.products
FOR EACH ROW EXECUTE FUNCTION public.sync_item_master_from_legacy('product');

CREATE TRIGGER packaging_sync_item_master
AFTER INSERT OR UPDATE OR DELETE ON public.packaging_items
FOR EACH ROW EXECUTE FUNCTION public.sync_item_master_from_legacy('packaging');

-- Master is tenant-readable. Legacy item editing remains at legacy endpoints;
-- no direct UPDATE/DELETE on master, preventing dual authority.
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

CREATE POLICY items_same_tenant_read ON public.items
FOR SELECT TO authenticated
USING (restaurant_id = public.current_restaurant_id());

-- New native services can be inserted by a real, active Backoffice user with
-- product administration permission; no service_role is required in a client.
CREATE FUNCTION public.can_create_native_service(p_restaurant uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN public.role_permissions rp ON rp.role_id = p.role_id
    JOIN public.permissions perm ON perm.id = rp.permission_id
    WHERE p.id = auth.uid()
      AND p.restaurant_id = p_restaurant
      AND p.is_active
      AND NOT p.is_pos_user
      AND perm.code = 'productos.gestionar'
  );
$$;

REVOKE ALL ON FUNCTION public.can_create_native_service(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_create_native_service(uuid)
  TO authenticated;

CREATE POLICY items_insert_native_service ON public.items
FOR INSERT TO authenticated
WITH CHECK (
  source_kind = 'native'
  AND item_class = 'service'
  AND item_type = 'service'
  AND public.can_create_native_service(restaurant_id)
);

-- Never grant direct update/delete of master at this stage.
GRANT SELECT, INSERT ON public.items TO authenticated;

-- Cross-tenant category references must be validated even when inserted by
-- security-definer code; standard FK alone would allow cross-tenant linkage.
CREATE FUNCTION public.validate_item_master_category_tenant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
BEGIN
  IF NEW.category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.product_categories c
    WHERE c.id = NEW.category_id
      AND c.restaurant_id = NEW.restaurant_id
  ) THEN
    RAISE EXCEPTION 'Item category belongs to another restaurant'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.validate_item_master_category_tenant()
  FROM PUBLIC;
CREATE TRIGGER item_master_category_tenant_guard
BEFORE INSERT OR UPDATE ON public.items
FOR EACH ROW
EXECUTE FUNCTION public.validate_item_master_category_tenant();

-- Assertion in the migration (no destructive cleanup or reset).
DO $$
DECLARE
  expected_count bigint;
  actual_count bigint;
BEGIN
  SELECT (SELECT count(*) FROM public.products)
       + (SELECT count(*) FROM public.packaging_items)
    INTO expected_count;
  SELECT count(*) INTO actual_count
  FROM public.items WHERE source_kind <> 'native';
  IF expected_count <> actual_count THEN
    RAISE EXCEPTION 'Item backfill cardinality mismatch: expected %, got %',
      expected_count, actual_count;
  END IF;
END;
$$;
