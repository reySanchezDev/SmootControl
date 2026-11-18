-- Disposable-only SQL fixture for the F2 private movement engine.
BEGIN;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('app.test_user', true),'')::uuid
$$;
CREATE TABLE public.items (
  id uuid PRIMARY KEY, restaurant_id uuid NOT NULL,
  item_type text NOT NULL, is_active boolean NOT NULL
);
CREATE TABLE public.pos_devices (
  id uuid PRIMARY KEY, restaurant_id uuid NOT NULL, is_active boolean NOT NULL
);
CREATE TABLE public.item_stock (
  restaurant_id uuid NOT NULL, item_id uuid NOT NULL,
  quantity_on_hand numeric(18,6) NOT NULL DEFAULT 0,
  version bigint NOT NULL DEFAULT 0, updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(restaurant_id,item_id)
);
CREATE TABLE public.item_ledger_entries (
  id text PRIMARY KEY, restaurant_id uuid NOT NULL, item_id uuid NOT NULL,
  movement_type text NOT NULL, quantity_delta numeric NOT NULL,
  unit_cost_base numeric NOT NULL, source_type text NOT NULL,
  source_id text NOT NULL, operation_key text NOT NULL,
  request_digest text NOT NULL, reversal_of_id text,
  device_id uuid, actor_id uuid, occurred_at timestamptz NOT NULL,
  UNIQUE(restaurant_id,operation_key)
);
CREATE UNIQUE INDEX item_ledger_one_reversal_idx
  ON public.item_ledger_entries(reversal_of_id)
  WHERE reversal_of_id IS NOT NULL;

-- Fixture authorization is deliberately minimal. Actual F1 authorization
-- was separately exercised with signed JWT and real role-permission tables.
CREATE FUNCTION public.app_item_has_write_access(uuid,text) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('app.can_write_inventory',true),'')::boolean IS TRUE
$$;

-- Same canonical arguments as actual F1 request-digest RPC.
CREATE FUNCTION public.item_movement_request_digest(
  p_id text,p_restaurant_id uuid,p_item_id uuid,p_movement_type text,
  p_quantity_delta numeric,p_source_type text,p_source_id text,
  p_operation_key text,p_unit_cost_base numeric,p_reversal_of_id text,
  p_device_id uuid,p_actor_id uuid,p_occurred_at timestamptz
) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT md5(convert_to(jsonb_build_object(
    'id',p_id,'restaurant_id',p_restaurant_id,'item_id',p_item_id,
    'movement_type',p_movement_type,'quantity_delta',p_quantity_delta,
    'source_type',p_source_type,'source_id',p_source_id,
    'operation_key',p_operation_key,'unit_cost_base',p_unit_cost_base,
    'reversal_of_id',p_reversal_of_id,'device_id',p_device_id,
    'actor_id',p_actor_id,'occurred_at',p_occurred_at)::text,'UTF8'));
$$;
INSERT INTO public.items VALUES
 ('10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001','inventory',true),
 ('10000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001','service',true),
 ('10000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000002','inventory',true);
INSERT INTO public.pos_devices VALUES
 ('20000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',true);
SELECT set_config('app.test_user','30000000-0000-0000-0000-000000000001',true);
SELECT set_config('app.can_write_inventory','true',true);
