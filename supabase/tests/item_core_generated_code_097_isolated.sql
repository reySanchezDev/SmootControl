-- Disposable fixture exercising the actual migration 097.
-- Never run against a linked database.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA item_core_internal;
CREATE TABLE public.items (
  id uuid PRIMARY KEY, restaurant_id uuid NOT NULL, code text NOT NULL,
  name text NOT NULL, item_type text NOT NULL, base_unit_id uuid NOT NULL,
  base_unit_cost numeric NOT NULL, base_unit_price numeric NOT NULL,
  can_sell boolean NOT NULL, can_purchase boolean NOT NULL,
  visible_in_pos boolean NOT NULL, uses_recipe boolean NOT NULL,
  send_to_kitchen boolean NOT NULL, is_active boolean NOT NULL,
  updated_at timestamptz NOT NULL
);
CREATE UNIQUE INDEX fixture_code ON public.items(restaurant_id,lower(btrim(code)));
CREATE TABLE public.item_classifications (
  id uuid PRIMARY KEY, restaurant_id uuid NOT NULL, is_active boolean NOT NULL
);
CREATE TABLE public.item_classification_links (
  restaurant_id uuid NOT NULL, item_id uuid NOT NULL, classification_id uuid NOT NULL,
  PRIMARY KEY(restaurant_id,item_id,classification_id)
);
CREATE FUNCTION item_core_internal.assert_catalog_write(p_restaurant_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF p_restaurant_id::text IS DISTINCT FROM current_setting('fixture.tenant', true)
  THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
END; $$;
CREATE FUNCTION item_core_internal.bump_item_catalog_revision(uuid)
RETURNS void LANGUAGE plpgsql AS $$ BEGIN RETURN; END; $$;
INSERT INTO public.items VALUES (
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'art-15', 'Existing', 'inventory',
  '30000000-0000-4000-8000-000000000001',
  0, 0, false, true, false, false, false, true, now()
);
\ir ../migrations/097_item_master_generated_business_code.sql
BEGIN;
DO $$
DECLARE
  tenant uuid := '20000000-0000-4000-8000-000000000001';
  payload jsonb := '{"name":"Coca-Cola","item_type":"inventory","base_unit_id":"30000000-0000-4000-8000-000000000001"}';
  first_item public.items;
  modified public.items;
  second_item public.items;
BEGIN
  PERFORM set_config('fixture.tenant', tenant::text, true);
  first_item := public.app_upsert_item_v2(tenant,payload);
  IF first_item.code <> 'ART-16' THEN RAISE EXCEPTION 'initial numbering incorrect'; END IF;
  modified := public.app_upsert_item_v2(tenant,payload ||
    jsonb_build_object('id',first_item.id,'name','Coca-Cola edit','code','MANUAL'));
  IF modified.code <> first_item.code THEN RAISE EXCEPTION 'code changed on edit'; END IF;
  second_item := public.app_upsert_item_v2(tenant,payload || '{"code":"MANUAL"}');
  IF second_item.code <> 'ART-17' THEN RAISE EXCEPTION 'sequence consumed on edit or accepted manual code'; END IF;
  BEGIN
    PERFORM public.app_upsert_item_v2(tenant,payload ||
      '{"id":"10000000-0000-4000-8000-000000000099"}');
    RAISE EXCEPTION 'missing id accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.app_upsert_item_v2('20000000-0000-4000-8000-000000000002',payload);
    RAISE EXCEPTION 'wrong tenant accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  IF has_function_privilege('anon','public.app_upsert_item_v2(uuid,jsonb)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.app_upsert_item_v2(uuid,jsonb)','EXECUTE')
     OR has_sequence_privilege('authenticated','item_core_internal.item_business_code_seq','USAGE')
  THEN RAISE EXCEPTION 'incorrect privileges'; END IF;
END; $$;
ROLLBACK;
