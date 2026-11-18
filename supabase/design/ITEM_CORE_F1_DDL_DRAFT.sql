-- KIVO ITEM CORE / F1 DESIGN REVIEW DRAFT / 2026-11-10
-- DO NOT EXECUTE. DO NOT MOVE UNDER supabase/migrations.
-- This is a structural SQL specification, not a deployable migration.
-- Existing legacy writers and FK consumers remain active until F2 cutover.
-- No automatic triggers mirroring products/packaging_items into this model.
--
-- Preconditions for a future migration:
--   G0 closed; PostgreSQL migration ledger 001-087; 088 mirror NOT applied;
--   data/config backup; actual pg_catalog object hashes; coordinated POS cutover.
--
-- Application authority:
--   item master updated only by guarded RPC, never direct client DML;
--   new inventory ledger updated only by guarded transactional movement RPC.
--   RPC implementations and complete migration sequencing are intentionally
--   NOT defined here: they require F1/F2 transaction + authorization tests.

BEGIN;

-- 1. Item category reuse. Keep existing category rows/identities.
--    The F1 cutover will rename the existing product_categories table,
--    rather than create a competing hierarchy.
-- ALTER TABLE public.product_categories RENAME TO item_categories;
-- The actual rename and FK rewrites are NOT enabled in this draft.
-- The DDL below references product_categories to remain reviewable against
-- the audited 001-087 schema; replace all references atomically at cutover.

-- Existing category.id is PK, but composite tenant FK also needs a unique key.
-- This is a conservative additive constraint on the existing table.
ALTER TABLE public.product_categories
  ADD CONSTRAINT product_categories_tenant_id_unique
  UNIQUE(restaurant_id,id);

CREATE TABLE public.items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  code text NOT NULL,
  name text NOT NULL,
  item_type text NOT NULL CHECK (
    item_type IN ('inventory','non_inventory','service')
  ),
  category_id uuid,
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
  CONSTRAINT items_code_nonblank CHECK (length(btrim(code)) BETWEEN 1 AND 64),
  CONSTRAINT items_name_nonblank CHECK (length(btrim(name)) BETWEEN 1 AND 250),
  CONSTRAINT items_pos_requires_sellable CHECK
    (NOT visible_in_pos OR can_sell),
  CONSTRAINT items_recipe_nonservice CHECK
    (NOT uses_recipe OR item_type <> 'service'),
  CONSTRAINT items_tenant_id_unique UNIQUE (restaurant_id,id),
  CONSTRAINT items_category_tenant_fk FOREIGN KEY (restaurant_id,category_id)
    REFERENCES public.product_categories(restaurant_id,id)
    DEFERRABLE INITIALLY IMMEDIATE
);

CREATE UNIQUE INDEX items_tenant_code_ci_uidx
  ON public.items(restaurant_id,lower(btrim(code)));
CREATE INDEX items_active_type_idx
  ON public.items(restaurant_id,item_type,is_active);
CREATE INDEX items_category_idx
  ON public.items(restaurant_id,category_id);

-- 2. Classification N:M, independent of inventory/service type.
CREATE TABLE public.item_classifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  code text NOT NULL CHECK(length(btrim(code)) BETWEEN 1 AND 64),
  name text NOT NULL CHECK(length(btrim(name)) > 0),
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT item_classifications_tenant_id_uq UNIQUE(restaurant_id,id)
);
CREATE UNIQUE INDEX item_classifications_code_ci_uq
  ON public.item_classifications(restaurant_id,lower(btrim(code)));

CREATE TABLE public.item_classification_links (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  item_id uuid NOT NULL,
  classification_id uuid NOT NULL,
  PRIMARY KEY(restaurant_id,item_id,classification_id),
  FOREIGN KEY(restaurant_id,item_id)
    REFERENCES public.items(restaurant_id,id) ON DELETE CASCADE,
  FOREIGN KEY(restaurant_id,classification_id)
    REFERENCES public.item_classifications(restaurant_id,id)
);
CREATE INDEX item_classification_links_class_idx
  ON public.item_classification_links(restaurant_id,classification_id);

-- 3. Units and conversions. Each item owns exactly one base unit by
--    items.base_unit_id, with quantity 1. The RPC ensures the matching
--    item_units row exists and keeps it consistent atomically.
CREATE TABLE public.item_units (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  item_id uuid NOT NULL,
  unit_id uuid NOT NULL REFERENCES public.measurement_units(id),
  quantity_in_base numeric(18,8) NOT NULL CHECK(quantity_in_base > 0),
  is_purchase boolean NOT NULL DEFAULT false,
  is_sale boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  PRIMARY KEY(restaurant_id,item_id,unit_id),
  FOREIGN KEY(restaurant_id,item_id)
    REFERENCES public.items(restaurant_id,id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX item_one_purchase_unit_idx
  ON public.item_units(restaurant_id,item_id) WHERE is_purchase AND is_active;
CREATE UNIQUE INDEX item_one_sale_unit_idx
  ON public.item_units(restaurant_id,item_id) WHERE is_sale AND is_active;

-- 4. Canonical inventory. One stock scope per restaurant for V1.
--    Non-inventory/service items are rejected by the movement RPC, including
--    indirect callers such as POS sync or payroll. Stock is a projection.
CREATE TABLE public.item_stock (
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  item_id uuid NOT NULL,
  quantity_on_hand numeric(18,6) NOT NULL DEFAULT 0,
  version bigint NOT NULL DEFAULT 0 CHECK(version >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(restaurant_id,item_id),
  FOREIGN KEY(restaurant_id,item_id) REFERENCES public.items(restaurant_id,id)
);

CREATE TABLE public.item_ledger_entries (
  id text PRIMARY KEY CHECK(length(btrim(id)) > 0),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  item_id uuid NOT NULL,
  movement_type text NOT NULL CHECK(
    movement_type IN ('opening','purchase','sale','recipe_consumption',
      'packaging_consumption','staff_consumption','adjustment','reversal')
  ),
  quantity_delta numeric(18,6) NOT NULL CHECK(quantity_delta <> 0),
  unit_cost_base numeric(18,6) NOT NULL DEFAULT 0
    CHECK(unit_cost_base >= 0),
  source_type text NOT NULL CHECK(length(btrim(source_type)) > 0),
  source_id text NOT NULL CHECK(length(btrim(source_id)) > 0),
  operation_key text NOT NULL CHECK(length(btrim(operation_key)) > 0),
  request_digest text NOT NULL CHECK(length(btrim(request_digest)) > 0),
  reversal_of_id text,
  device_id uuid,
  actor_id uuid,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(restaurant_id,item_id) REFERENCES public.items(restaurant_id,id),
  FOREIGN KEY(reversal_of_id) REFERENCES public.item_ledger_entries(id),
  FOREIGN KEY(device_id) REFERENCES public.pos_devices(id),
  CONSTRAINT ledger_not_self_reverse CHECK
    (reversal_of_id IS NULL OR reversal_of_id <> id),
  CONSTRAINT ledger_reversal_type CHECK
    (reversal_of_id IS NULL OR movement_type = 'reversal'),
  CONSTRAINT item_ledger_tenant_operation_uq
    UNIQUE(restaurant_id,operation_key)
);
CREATE UNIQUE INDEX item_ledger_one_reversal_idx
  ON public.item_ledger_entries(reversal_of_id)
  WHERE reversal_of_id IS NOT NULL;
CREATE INDEX item_ledger_item_time_idx
  ON public.item_ledger_entries(restaurant_id,item_id,occurred_at);

-- A self-FK by reversal_of_id alone does not prove same tenant/item.
-- Use a composite FK so no cross-tenant or cross-item reversal can occur.
ALTER TABLE public.item_ledger_entries
  ADD CONSTRAINT item_ledger_tenant_item_id_uq
  UNIQUE(restaurant_id,item_id,id);
ALTER TABLE public.item_ledger_entries
  DROP CONSTRAINT item_ledger_entries_reversal_of_id_fkey;
ALTER TABLE public.item_ledger_entries
  ADD CONSTRAINT item_ledger_reversal_tenant_fk
  FOREIGN KEY(restaurant_id,item_id,reversal_of_id)
  REFERENCES public.item_ledger_entries(restaurant_id,item_id,id);

-- 5. Rules are not attributes of packaging, and a consumed item can be used
--    both as a normal product and as packaging, subject to explicit policies.
--    Null sales_type/source indicate applicability at restaurant level;
--    rule precedence is determined by a single resolution RPC in F2.
-- A same-tenant sales_type FK requires a unique composite target.
ALTER TABLE public.sales_types
  ADD CONSTRAINT sales_types_tenant_id_unique UNIQUE(restaurant_id,id);

CREATE TABLE public.item_consumption_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES public.restaurants(id),
  source_item_id uuid,
  consumed_item_id uuid NOT NULL,
  sales_type_id uuid,
  scope text NOT NULL CHECK(scope IN ('per_sale_line','per_order')),
  quantity numeric(18,6) NOT NULL CHECK(quantity > 0),
  unit_id uuid NOT NULL REFERENCES public.measurement_units(id),
  priority integer NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(restaurant_id,id),
  FOREIGN KEY(restaurant_id,source_item_id)
    REFERENCES public.items(restaurant_id,id),
  FOREIGN KEY(restaurant_id,consumed_item_id)
    REFERENCES public.items(restaurant_id,id),
  FOREIGN KEY(restaurant_id,sales_type_id)
    REFERENCES public.sales_types(restaurant_id,id),
  CONSTRAINT consumption_line_has_source CHECK(
    scope <> 'per_sale_line' OR source_item_id IS NOT NULL
  ),
  CONSTRAINT consumption_no_self_link CHECK(
    source_item_id IS NULL OR source_item_id <> consumed_item_id
  )
);
CREATE INDEX item_consumption_rules_lookup_idx
  ON public.item_consumption_rules
  (restaurant_id,sales_type_id,source_item_id,scope,priority)
  WHERE is_active;

-- 6. Tenant-scoped read policies. Zero direct writes by anon or authenticated
--    clients; writes are performed by future security-hardened RPC functions.
ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_classifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_classification_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_consumption_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY items_tenant_read ON public.items
 FOR SELECT TO authenticated
 USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_classifications_tenant_read ON public.item_classifications
 FOR SELECT TO authenticated
 USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_classification_links_tenant_read ON public.item_classification_links
 FOR SELECT TO authenticated
 USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_units_tenant_read ON public.item_units
 FOR SELECT TO authenticated
 USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_stock_tenant_read ON public.item_stock
 FOR SELECT TO authenticated
 USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_ledger_entries_tenant_read ON public.item_ledger_entries
 FOR SELECT TO authenticated
 USING (restaurant_id = public.current_restaurant_id());
CREATE POLICY item_consumption_rules_tenant_read ON public.item_consumption_rules
 FOR SELECT TO authenticated
 USING (restaurant_id = public.current_restaurant_id());

REVOKE ALL ON public.items,
  public.item_classifications, public.item_classification_links,
  public.item_units, public.item_stock, public.item_ledger_entries,
  public.item_consumption_rules FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.items, public.item_classifications,
  public.item_classification_links, public.item_units, public.item_stock,
  public.item_ledger_entries, public.item_consumption_rules TO authenticated;

-- Migration itself is only schema-only. Do not backfill legacy rows here.
-- No triggers on products/packaging_items, no sale/stock updates, no DROPs.
-- This transaction is an illustrative DDL review: its safe execution
-- and rollback protocol require an isolated database and approved gate.
ROLLBACK;
