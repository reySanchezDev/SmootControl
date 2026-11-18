-- Isolated-only fixture for sale/void v2 contract; never use on lab/main.
BEGIN;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('app.test_user',true),'')::uuid;
$$;
CREATE FUNCTION public.current_restaurant_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('app.test_restaurant',true),'')::uuid;
$$;
CREATE TABLE public.restaurants(id uuid PRIMARY KEY);
CREATE TABLE public.product_categories(
 id uuid PRIMARY KEY,restaurant_id uuid NOT NULL,name text NOT NULL
);
CREATE TABLE public.items(
 id uuid PRIMARY KEY,restaurant_id uuid NOT NULL,
 code text NOT NULL,name text NOT NULL,
 item_type text NOT NULL,category_id uuid,base_unit_id uuid NOT NULL,
 base_unit_cost numeric NOT NULL,base_unit_price numeric NOT NULL,
 can_sell boolean NOT NULL,uses_recipe boolean NOT NULL,
 send_to_kitchen boolean NOT NULL,is_active boolean NOT NULL,
 UNIQUE(restaurant_id,id)
);
CREATE TABLE public.measurement_units(
 id uuid PRIMARY KEY,restaurant_id uuid,unit_group text NOT NULL,
 base_factor numeric NOT NULL,is_active boolean NOT NULL
);
CREATE TABLE public.sales_types(
 id uuid PRIMARY KEY,restaurant_id uuid NOT NULL,is_active boolean NOT NULL
);
CREATE TABLE public.item_consumption_rules(
 id uuid PRIMARY KEY,restaurant_id uuid NOT NULL,
 source_item_id uuid,consumed_item_id uuid NOT NULL,
 sales_type_id uuid,scope text NOT NULL,quantity numeric NOT NULL,
 unit_id uuid NOT NULL,priority integer NOT NULL,is_active boolean NOT NULL,
 UNIQUE(restaurant_id,id)
);
CREATE TABLE public.pos_devices(
 id uuid PRIMARY KEY,restaurant_id uuid NOT NULL,is_active boolean NOT NULL
);
CREATE TABLE public.cash_register_sessions(
 id uuid PRIMARY KEY,restaurant_id uuid NOT NULL,pos_device_id uuid,
 cashier_user_id uuid NOT NULL,status text NOT NULL
);
CREATE TABLE public.payment_methods(
 id uuid PRIMARY KEY,restaurant_id uuid,is_active boolean NOT NULL
);
CREATE TABLE public.invoice_number_settings(
 restaurant_id uuid PRIMARY KEY,prefix text,
 initial_number bigint NOT NULL DEFAULT 1,
 next_number bigint NOT NULL DEFAULT 1
);
CREATE TABLE public.sales(
 id uuid PRIMARY KEY,local_id text,
 restaurant_id uuid NOT NULL,cash_register_session_id uuid,
 user_id uuid NOT NULL,payment_method_id uuid NOT NULL,
 sales_type_id uuid,invoice_number text NOT NULL,
 total_amount numeric NOT NULL,total_cost numeric NOT NULL,
 gross_profit numeric NOT NULL,status text NOT NULL,
 sync_status text NOT NULL,sold_at timestamptz NOT NULL,
 pos_device_id uuid,payment_reference text,
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(restaurant_id,invoice_number)
);
CREATE TABLE public.sale_items(
 id uuid PRIMARY KEY,sale_id uuid NOT NULL REFERENCES public.sales(id),
 product_code text NOT NULL,product_name text NOT NULL,
 category_id uuid,category_name text NOT NULL,
 quantity numeric NOT NULL,unit_price numeric NOT NULL,
 unit_cost numeric NOT NULL,subtotal numeric NOT NULL,
 gross_profit numeric NOT NULL
);
CREATE TABLE public.sale_voids(
 id uuid PRIMARY KEY,sale_id uuid NOT NULL UNIQUE REFERENCES public.sales(id),
 restaurant_id uuid NOT NULL,cash_register_session_id uuid,
 voided_by_user_id uuid NOT NULL,reason text NOT NULL,
 original_total_amount numeric NOT NULL,original_payment_method_id uuid,
 original_payment_reference text,sync_status text NOT NULL,
 voided_at timestamptz NOT NULL
);
CREATE TABLE public.item_stock(
 restaurant_id uuid NOT NULL,item_id uuid NOT NULL,
 quantity_on_hand numeric(18,6) NOT NULL DEFAULT 0,
 version bigint NOT NULL DEFAULT 0,updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(restaurant_id,item_id)
);
CREATE TABLE public.item_ledger_entries(
 id text PRIMARY KEY,restaurant_id uuid NOT NULL,item_id uuid NOT NULL,
 movement_type text NOT NULL,quantity_delta numeric NOT NULL,
 unit_cost_base numeric NOT NULL,source_type text NOT NULL,
 source_id text NOT NULL,operation_key text NOT NULL,request_digest text NOT NULL,
 reversal_of_id text,device_id uuid,actor_id uuid,occurred_at timestamptz NOT NULL,
 UNIQUE(restaurant_id,operation_key),
 UNIQUE(restaurant_id,item_id,id)
);
CREATE UNIQUE INDEX item_ledger_one_reversal_idx
 ON public.item_ledger_entries(reversal_of_id)
 WHERE reversal_of_id IS NOT NULL;

CREATE FUNCTION public.app_item_has_write_access(uuid,text)
RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('app.can_write_inventory',true),'')::boolean IS TRUE
$$;
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
CREATE FUNCTION public.assert_pos_device(uuid,uuid,text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
 IF $3 IS DISTINCT FROM 'fixture-secret' OR NOT EXISTS (
  SELECT 1 FROM public.pos_devices
  WHERE restaurant_id=$1 AND id=$2 AND is_active=true
 ) THEN
  RAISE EXCEPTION 'invalid_device_credentials' USING ERRCODE='42501';
 END IF;
END; $$;

INSERT INTO public.restaurants VALUES
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002');
INSERT INTO public.measurement_units VALUES
 ('10000000-0000-0000-0000-000000000001',NULL,'count',1,true);
INSERT INTO public.product_categories VALUES
 ('11000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001','Bebidas');
INSERT INTO public.items VALUES
 ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',
  'BOT-1','Botella','inventory','11000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',3,7,true,false,false,true),
 ('30000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',
  'BAG-1','Bolsa','inventory',NULL,
  '10000000-0000-0000-0000-000000000001',1,0,false,false,false,true),
 ('30000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001',
  'SRV-1','Servicio','service',NULL,
  '10000000-0000-0000-0000-000000000001',0,5,true,false,false,true),
 ('30000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001',
  'NAP-1','Servilleta','non_inventory',NULL,
  '10000000-0000-0000-0000-000000000001',0,0,false,false,false,true);
INSERT INTO public.sales_types VALUES
 ('20000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',true);
INSERT INTO public.item_consumption_rules VALUES
 ('40000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  NULL,'30000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000001','per_order',1,
  '10000000-0000-0000-0000-000000000001',10,true),
 ('40000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000004',
  '20000000-0000-0000-0000-000000000001','per_sale_line',1,
  '10000000-0000-0000-0000-000000000001',20,true);
INSERT INTO public.pos_devices VALUES
 ('50000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',true);
INSERT INTO public.cash_register_sessions VALUES
 ('60000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000001','open');
INSERT INTO public.payment_methods VALUES
 ('80000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',true);

SELECT set_config('app.test_user','70000000-0000-0000-0000-000000000001',true);
SELECT set_config('app.test_restaurant','00000000-0000-0000-0000-000000000001',true);
SELECT set_config('app.can_write_inventory','false',true);
