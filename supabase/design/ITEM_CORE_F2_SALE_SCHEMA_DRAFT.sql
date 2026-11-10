-- KIVO F2 / SALES AND CONSUMPTION SNAPSHOT / SCHEMA CONTRACT
-- DO NOT EXECUTE on any operating database. NOT a migration.
-- Intended for PostgreSQL 16 disposable compatibility fixtures.
-- Depends on existing sales/sale_items/sale_voids and canonical F1 items.
-- This structural draft does NOT implement pos_sync_sale_v2 or void.
-- It preserves old product_id fields until a fully coordinated F2 cutover.
BEGIN;

-- The business transaction, not individual stock events, owns idempotency.
ALTER TABLE public.sales
  ADD CONSTRAINT sales_tenant_id_unique UNIQUE(restaurant_id,id);
ALTER TABLE public.sales
  ADD COLUMN sync_contract_version integer NOT NULL DEFAULT 1
    CHECK(sync_contract_version >= 1),
  ADD COLUMN operation_key text,
  ADD COLUMN operation_digest text;
ALTER TABLE public.sales
  ADD CONSTRAINT sales_v2_operation_pair CHECK (
    (operation_key IS NULL AND operation_digest IS NULL)
    OR (operation_key IS NOT NULL AND length(btrim(operation_key)) > 0
        AND operation_digest IS NOT NULL AND length(btrim(operation_digest)) > 0)
  ),
  ADD CONSTRAINT sales_v2_requires_operation CHECK (
    sync_contract_version < 2 OR operation_key IS NOT NULL
  );
CREATE UNIQUE INDEX sales_tenant_operation_key_uq
  ON public.sales(restaurant_id,operation_key)
  WHERE operation_key IS NOT NULL;

-- Keep existing historical product_code/product_name snapshot columns until
-- the cutover: values in the future V2 flow must come from items, not UUIDs.
-- Multiple clients may still refer to product_id until F2 switch-off.
ALTER TABLE public.sale_items
  ADD COLUMN restaurant_id uuid,
  ADD COLUMN item_id uuid,
  ADD COLUMN item_base_unit_id uuid,
  ADD COLUMN item_unit_factor numeric(18,8)
    CHECK(item_unit_factor IS NULL OR item_unit_factor > 0),
  ADD COLUMN sync_contract_version integer NOT NULL DEFAULT 1;
-- Do not set NOT NULL until rows from old test history are discarded/mapped.
ALTER TABLE public.sale_items
  ADD CONSTRAINT sale_items_tenant_sale_fk
    FOREIGN KEY(restaurant_id,sale_id)
    REFERENCES public.sales(restaurant_id,id),
  ADD CONSTRAINT sale_items_tenant_item_fk
    FOREIGN KEY(restaurant_id,item_id)
    REFERENCES public.items(restaurant_id,id),
  ADD CONSTRAINT sale_items_v2_valid_item CHECK(
    sync_contract_version < 2 OR
      (restaurant_id IS NOT NULL AND item_id IS NOT NULL
       AND item_base_unit_id IS NOT NULL AND item_unit_factor IS NOT NULL)
  ),
  ADD CONSTRAINT sale_items_tenant_sale_id_unique
    UNIQUE(restaurant_id,sale_id,id);

-- The void is a separate idempotent business operation, not another sale.
ALTER TABLE public.sale_voids
  ADD COLUMN operation_key text,
  ADD COLUMN operation_digest text;
ALTER TABLE public.sale_voids
  ADD CONSTRAINT sale_voids_operation_pair CHECK (
    (operation_key IS NULL AND operation_digest IS NULL)
    OR (operation_key IS NOT NULL AND length(btrim(operation_key)) > 0
        AND operation_digest IS NOT NULL AND length(btrim(operation_digest)) > 0)
  ),
  ADD CONSTRAINT sale_voids_tenant_sale_fk
    FOREIGN KEY(restaurant_id,sale_id)
    REFERENCES public.sales(restaurant_id,id);
CREATE UNIQUE INDEX sale_voids_tenant_operation_uq
  ON public.sale_voids(restaurant_id,operation_key)
  WHERE operation_key IS NOT NULL;

-- Persist the exact rule-resolution outcome used by each completed sale.
-- Reversals use the original ledger movements and frozen snapshots: they do
-- not invoke current recipe or consumption rules.
CREATE TABLE public.sale_consumption_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL,
  sale_id uuid NOT NULL,
  sale_line_id uuid,
  scope text NOT NULL CHECK (scope IN('per_order','per_sale_line')),
  consumed_item_id uuid NOT NULL,
  rule_id uuid,
  quantity_base numeric(18,6) NOT NULL CHECK(quantity_base > 0),
  unit_cost_base numeric(18,6) NOT NULL CHECK(unit_cost_base >= 0),
  movement_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sale_consumption_snapshot_scope CHECK(
    (scope='per_order' AND sale_line_id IS NULL)
    OR (scope='per_sale_line' AND sale_line_id IS NOT NULL)
  ),
  FOREIGN KEY(restaurant_id,sale_id)
    REFERENCES public.sales(restaurant_id,id),
  FOREIGN KEY(restaurant_id,sale_id,sale_line_id)
    REFERENCES public.sale_items(restaurant_id,sale_id,id),
  FOREIGN KEY(restaurant_id,consumed_item_id)
    REFERENCES public.items(restaurant_id,id),
  FOREIGN KEY(restaurant_id,rule_id)
    REFERENCES public.item_consumption_rules(restaurant_id,id),
  FOREIGN KEY(restaurant_id,consumed_item_id,movement_id)
    REFERENCES public.item_ledger_entries(restaurant_id,item_id,id),
  -- Physical inventory consumption MUST include a committed ledger entry.
  CONSTRAINT sale_consumption_snapshot_has_movement CHECK(
    movement_id IS NOT NULL AND length(btrim(movement_id)) > 0
  )
);
CREATE INDEX sale_consumption_snapshots_sale_idx
  ON public.sale_consumption_snapshots(restaurant_id,sale_id);
CREATE UNIQUE INDEX sale_consumption_snapshot_movement_uq
  ON public.sale_consumption_snapshots(movement_id);

-- Preserve every recipe leaf path/version at the moment of sale. An item may
-- occur through several branches of a nested recipe; each leaf has its own
-- snapshot, while the actual physical ledger is aggregated per line+item.
CREATE TABLE public.sale_recipe_consumption_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL,
  sale_id uuid NOT NULL,
  sale_line_id uuid NOT NULL,
  root_item_id uuid NOT NULL,
  component_item_id uuid NOT NULL,
  quantity_base numeric(18,6) NOT NULL CHECK(quantity_base>0),
  unit_cost_base numeric(18,6) NOT NULL CHECK(unit_cost_base>=0),
  recipe_trace jsonb NOT NULL
    CHECK(jsonb_typeof(recipe_trace)='array' AND jsonb_array_length(recipe_trace)>0),
  movement_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(restaurant_id,sale_id,sale_line_id)
    REFERENCES public.sale_items(restaurant_id,sale_id,id),
  FOREIGN KEY(restaurant_id,root_item_id)
    REFERENCES public.items(restaurant_id,id),
  FOREIGN KEY(restaurant_id,component_item_id)
    REFERENCES public.items(restaurant_id,id),
  FOREIGN KEY(restaurant_id,component_item_id,movement_id)
    REFERENCES public.item_ledger_entries(restaurant_id,item_id,id)
);
CREATE INDEX sale_recipe_consumption_snapshots_sale_idx
  ON public.sale_recipe_consumption_snapshots(restaurant_id,sale_id,sale_line_id);

-- Tenant scoping must still be applied to the existing sales tables by F2.
ALTER TABLE public.sale_consumption_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_recipe_consumption_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY sale_consumption_snapshots_tenant_read
  ON public.sale_consumption_snapshots FOR SELECT TO authenticated
  USING(restaurant_id=public.current_restaurant_id());
CREATE POLICY sale_recipe_consumption_snapshots_tenant_read
  ON public.sale_recipe_consumption_snapshots FOR SELECT TO authenticated
  USING(restaurant_id=public.current_restaurant_id());
REVOKE ALL ON public.sale_consumption_snapshots,
  public.sale_recipe_consumption_snapshots
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.sale_consumption_snapshots,
  public.sale_recipe_consumption_snapshots TO authenticated;

-- No backfill and no DML. A later POS sale RPC must make all these writes
-- atomic, resolve rule snapshots, call the trusted stock engine and return
-- a canonical response with operation digest validation.
ROLLBACK;
