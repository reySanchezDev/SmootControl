-- Disposable PostgreSQL regression for 095: two-step historical cost recomputation.
-- Never run against a linked or production database.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE public.sales (
  id uuid PRIMARY KEY,
  restaurant_id uuid NOT NULL,
  status text NOT NULL,
  total_amount numeric NOT NULL,
  total_cost numeric NOT NULL DEFAULT 0,
  gross_profit numeric NOT NULL DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);
CREATE TABLE public.sale_items (
  id uuid PRIMARY KEY,
  sale_id uuid NOT NULL REFERENCES public.sales(id),
  product_id uuid,
  quantity numeric NOT NULL,
  unit_price numeric NOT NULL,
  unit_cost numeric NOT NULL,
  gross_profit numeric NOT NULL
);
CREATE FUNCTION public.app_current_sale_item_unit_cost(uuid,uuid)
RETURNS numeric LANGUAGE sql AS $$ SELECT 4::numeric $$;
\ir ../migrations/095_fix_sale_cost_backfill_temp_table.sql

BEGIN;
INSERT INTO public.sales(id,restaurant_id,status,total_amount,total_cost,gross_profit)
VALUES
('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','completed',30,0,30),
('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','completed',20,0,20),
('33333333-3333-4333-8333-333333333333','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','pending',10,0,10);
INSERT INTO public.sale_items(id,sale_id,product_id,quantity,unit_price,unit_cost,gross_profit)
VALUES
('11111111-1111-4111-8111-000000000001','11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-000000000001',2,10,0,20),
('11111111-1111-4111-8111-000000000002','11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-000000000002',1,10,2,8),
('22222222-2222-4222-8222-000000000001','22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-000000000001',2,10,0,20),
('33333333-3333-4333-8333-000000000001','33333333-3333-4333-8333-333333333333','aaaaaaaa-aaaa-4aaa-8aaa-000000000003',1,10,0,10);

DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.app_backfill_missing_sale_costs('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  IF v_result <> '{"updated_items":1,"updated_sales":1}'::jsonb THEN
    RAISE EXCEPTION 'Unexpected first response %',v_result;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.sales
    WHERE id='11111111-1111-4111-8111-111111111111'
      AND total_cost=10 AND gross_profit=20
  ) THEN RAISE EXCEPTION 'Sale totals did not include updated and prior line costs'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.sale_items
    WHERE id='11111111-1111-4111-8111-000000000001'
      AND unit_cost=4 AND gross_profit=12
  ) THEN RAISE EXCEPTION 'Item snapshot not recalculated'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.sale_items
    WHERE sale_id IN ('22222222-2222-4222-8222-222222222222',
                      '33333333-3333-4333-8333-333333333333')
      AND unit_cost<>0
  ) THEN RAISE EXCEPTION 'Other tenant or unfinished sale modified'; END IF;
  v_result := public.app_backfill_missing_sale_costs('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  IF v_result <> '{"updated_items":0,"updated_sales":0}'::jsonb THEN
    RAISE EXCEPTION 'Backfill is not idempotent %',v_result;
  END IF;
END;
$$;
ROLLBACK;
