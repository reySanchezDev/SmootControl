-- Isolated PostgreSQL 16-only mock of post-F1 sales dependencies.
-- Executed by GitHub Actions inside a single transaction with DDL and asserts.
BEGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE anon NOLOGIN;
CREATE FUNCTION public.current_restaurant_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('app.test_restaurant',true),'')::uuid;
$$;
CREATE TABLE public.items(
 id uuid PRIMARY KEY, restaurant_id uuid NOT NULL,
 UNIQUE(restaurant_id,id)
);
CREATE TABLE public.item_consumption_rules(
 id uuid PRIMARY KEY,restaurant_id uuid NOT NULL,
 UNIQUE(restaurant_id,id)
);
CREATE TABLE public.item_ledger_entries(
 id text PRIMARY KEY, restaurant_id uuid NOT NULL,
 item_id uuid NOT NULL, UNIQUE(restaurant_id,item_id,id)
);
CREATE TABLE public.sales(
 id uuid PRIMARY KEY, restaurant_id uuid NOT NULL
);
CREATE TABLE public.sale_items(
 id uuid PRIMARY KEY, sale_id uuid NOT NULL REFERENCES public.sales(id),
 product_code text NOT NULL DEFAULT '', product_name text NOT NULL DEFAULT ''
);
CREATE TABLE public.sale_voids(
 id uuid PRIMARY KEY, sale_id uuid NOT NULL REFERENCES public.sales(id),
 restaurant_id uuid NOT NULL
);
INSERT INTO public.items VALUES
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
INSERT INTO public.item_consumption_rules VALUES
 ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
INSERT INTO public.sales VALUES
 ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
INSERT INTO public.item_ledger_entries VALUES
 ('movement-01','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'),
 ('movement-b','00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002');
