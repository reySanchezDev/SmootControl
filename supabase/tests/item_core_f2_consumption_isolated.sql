-- ISOLATED CONTRACT TEST: PostgreSQL service container only.
-- No production or local Docker access. psql -v ON_ERROR_STOP=1
-- Run with: psql -f supabase/tests/item_core_f2_consumption_isolated.sql
BEGIN;
CREATE SCHEMA IF NOT EXISTS public;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE anon NOLOGIN;
CREATE FUNCTION public.current_restaurant_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('app.test_restaurant',true),'')::uuid;
$$;
CREATE TABLE public.items (
  id uuid PRIMARY KEY, restaurant_id uuid NOT NULL,
  item_type text NOT NULL, is_active boolean NOT NULL,
  can_sell boolean NOT NULL, base_unit_id uuid NOT NULL
);
CREATE TABLE public.sales_types (
  id uuid PRIMARY KEY, restaurant_id uuid NOT NULL, is_active boolean NOT NULL
);
CREATE TABLE public.measurement_units (
  id uuid PRIMARY KEY, restaurant_id uuid,
  unit_group text NOT NULL, base_factor numeric NOT NULL,
  is_active boolean NOT NULL
);
CREATE TABLE public.item_consumption_rules (
  id uuid PRIMARY KEY, restaurant_id uuid NOT NULL,
  source_item_id uuid, consumed_item_id uuid NOT NULL,
  sales_type_id uuid, scope text NOT NULL,
  quantity numeric NOT NULL, unit_id uuid NOT NULL,
  priority integer NOT NULL, is_active boolean NOT NULL
);
INSERT INTO public.measurement_units VALUES
  ('10000000-0000-0000-0000-000000000001',NULL,'count',1,true),
  ('10000000-0000-0000-0000-000000000002',NULL,'count',12,true),
  ('10000000-0000-0000-0000-000000000003',NULL,'mass',1000,true);
INSERT INTO public.sales_types VALUES
  ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',true),
  ('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002',true);
INSERT INTO public.items VALUES
  ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','non_inventory',true,true,'10000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','inventory',true,false,'10000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','inventory',true,false,'10000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000002','inventory',true,false,'10000000-0000-0000-0000-000000000001');
-- Global line rule and specific line rule: specific sales type wins.
-- Two identical order lines must aggregate into four individual packs.
INSERT INTO public.item_consumption_rules VALUES
  ('40000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002',
   NULL,'per_sale_line',1,'10000000-0000-0000-0000-000000000001',20,true),
  ('40000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002',
   '20000000-0000-0000-0000-000000000001','per_sale_line',2,
   '10000000-0000-0000-0000-000000000001',100,true),
  ('40000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001',
   NULL,'30000000-0000-0000-0000-000000000003',
   '20000000-0000-0000-0000-000000000001','per_order',1,
   '10000000-0000-0000-0000-000000000001',100,true);

\i supabase/design/ITEM_CORE_F2_CONSUMPTION_DRAFT.sql
SELECT set_config('app.test_restaurant','00000000-0000-0000-0000-000000000001',true);

DO $$
DECLARE
  v_lines jsonb := '[{"item_id":"30000000-0000-0000-0000-000000000001","quantity":1},{"item_id":"30000000-0000-0000-0000-000000000001","quantity":1}]';
  v_line_qty numeric;
  v_order_qty numeric;
  v_rows integer;
BEGIN
  SELECT count(*),
    max(quantity_base) FILTER (WHERE scope='per_sale_line'),
    max(quantity_base) FILTER (WHERE scope='per_order')
  INTO v_rows,v_line_qty,v_order_qty
  FROM public.resolve_item_consumption(
    '00000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',v_lines);
  IF v_rows<>2 OR v_line_qty<>4 OR v_order_qty<>1 THEN
    RAISE EXCEPTION 'wrong_consumption: rows %, line %, order %',
      v_rows,v_line_qty,v_order_qty;
  END IF;

  -- Duplicate best-ranked rules reject ambiguity instead of double counting.
  INSERT INTO public.item_consumption_rules VALUES
    ('40000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001',
     '30000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002',
     '20000000-0000-0000-0000-000000000001','per_sale_line',1,
     '10000000-0000-0000-0000-000000000001',100,true);
  BEGIN
    PERFORM * FROM public.resolve_item_consumption(
      '00000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000001',v_lines);
    RAISE EXCEPTION 'missing_ambiguous_rule_rejection';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'ambiguous_consumption_rules' THEN RAISE; END IF;
  END;
  DELETE FROM public.item_consumption_rules
  WHERE id='40000000-0000-0000-0000-000000000004';

  -- Invalid dimensions must error; do not quietly skip stock consumption.
  UPDATE public.item_consumption_rules
    SET unit_id='10000000-0000-0000-0000-000000000003'
    WHERE id='40000000-0000-0000-0000-000000000003';
  BEGIN
    PERFORM * FROM public.resolve_item_consumption(
      '00000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000001',v_lines);
    RAISE EXCEPTION 'missing_unit_mismatch_rejection';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'invalid_consumption_rule_unit' THEN RAISE; END IF;
  END;
  UPDATE public.item_consumption_rules
    SET unit_id='10000000-0000-0000-0000-000000000001'
    WHERE id='40000000-0000-0000-0000-000000000003';

  -- Never permit a different tenant to inspect rule resolution.
  BEGIN
    PERFORM * FROM public.resolve_item_consumption(
      '00000000-0000-0000-0000-000000000002',
      '20000000-0000-0000-0000-000000000002',v_lines);
    RAISE EXCEPTION 'missing_tenant_rejection';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLERRM <> 'consumption_tenant_not_authorized' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'PASS F2 isolated rule resolver: line, order, priority, ambiguity, units, tenant';
END;
$$;
ROLLBACK;
