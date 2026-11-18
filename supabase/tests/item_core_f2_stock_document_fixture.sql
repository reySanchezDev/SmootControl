-- Append to item_core_f2_internal_ledger_fixture.sql in one disposable DB.
-- Existing fixture starts BEGIN and sets auth.uid() and inventory permission.
CREATE TABLE public.restaurants (id uuid PRIMARY KEY);
CREATE TABLE auth.users (id uuid PRIMARY KEY);
INSERT INTO public.restaurants(id) VALUES
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002');
INSERT INTO auth.users(id) VALUES
 ('30000000-0000-0000-0000-000000000001');

ALTER TABLE public.items
  ADD COLUMN base_unit_id uuid,
  ADD COLUMN can_purchase boolean NOT NULL DEFAULT false,
  ADD COLUMN base_unit_cost numeric NOT NULL DEFAULT 0;

CREATE TABLE public.item_units (
  restaurant_id uuid NOT NULL,
  item_id uuid NOT NULL,
  unit_id uuid NOT NULL,
  quantity_in_base numeric(18,8) NOT NULL,
  is_purchase boolean NOT NULL,
  is_active boolean NOT NULL
);
CREATE FUNCTION public.current_restaurant_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('app.test_restaurant',true),'')::uuid
$$;

UPDATE public.items SET
  base_unit_id='80000000-0000-0000-0000-000000000001',
  can_purchase=true,base_unit_cost=4
WHERE id='10000000-0000-0000-0000-000000000001';

UPDATE public.items SET
  base_unit_id='80000000-0000-0000-0000-000000000001'
WHERE id='10000000-0000-0000-0000-000000000002';

INSERT INTO public.item_units VALUES
 ('00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '80000000-0000-0000-0000-000000000001',1,false,true),
 ('00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '80000000-0000-0000-0000-000000000002',12,true,true),
 ('00000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  '80000000-0000-0000-0000-000000000001',1,true,true);

SELECT set_config(
  'app.test_restaurant','00000000-0000-0000-0000-000000000001',true
);
