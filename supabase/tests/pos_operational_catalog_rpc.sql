BEGIN;

SELECT plan(8);

INSERT INTO public.restaurants(id, commercial_name)
VALUES ('f1350000-0000-0000-0000-000000000001', 'Sync RPC fixture');
INSERT INTO public.pos_devices(id, restaurant_id, name, secret_hash)
VALUES (
  'f1350000-0000-0000-0000-000000000002',
  'f1350000-0000-0000-0000-000000000001',
  'Sync RPC fixture device',
  encode(digest('fixture-secret', 'sha256'), 'hex')
);
INSERT INTO public.item_catalog_revisions(restaurant_id)
VALUES ('f1350000-0000-0000-0000-000000000001');

CREATE TEMP TABLE pos_catalog_response AS
SELECT public.pos_pull_operational_catalog(
  'f1350000-0000-0000-0000-000000000001',
  'f1350000-0000-0000-0000-000000000002',
  'fixture-secret'
) AS payload;

SELECT ok(
  (SELECT payload ?& ARRAY[
    'restaurants', 'invoice_number_settings', 'permissions', 'roles',
    'role_permissions', 'profiles', 'product_categories', 'modifier_groups',
    'modifier_options', 'item_modifier_groups', 'items', 'products',
    'inventory_stock', 'sales_types', 'packaging_items',
    'item_consumption_rules', 'product_packaging_rules', 'packaging_stock',
    'payment_methods', 'restaurant_tables', 'expense_categories',
    'exchange_rates', 'cash_register_sessions', 'employees', 'business_rules',
    'item_catalog_v2'
  ] FROM pos_catalog_response),
  'device RPC returns every catalog collection consumed by current/compatible clients'
);
SELECT is(
  (SELECT jsonb_typeof(payload->'items') FROM pos_catalog_response),
  'array', 'canonical item collection is an array'
);
SELECT is(
  (SELECT jsonb_typeof(payload->'products') FROM pos_catalog_response),
  'array', 'compatibility alias is projected without the dropped products table'
);
SELECT is(
  (SELECT payload#>>'{item_catalog_v2,snapshot_complete}'
   FROM pos_catalog_response),
  'true', 'canonical snapshot is complete'
);
SELECT ok(
  to_regprocedure(
    'public.pos_pull_operational_catalog_legacy_20261117(uuid,uuid,text)'
  ) IS NULL,
  'successful pull does not require the removed legacy function'
);
SELECT throws_ok(
  $$SELECT public.pos_pull_operational_catalog(
    'f1350000-0000-0000-0000-000000000001',
    'f1350000-0000-0000-0000-000000000002', 'wrong-secret')$$,
  '42501', 'Dispositivo POS no autorizado',
  'invalid device secret is rejected'
);
SELECT throws_ok(
  $$SELECT public.pos_pull_operational_catalog(
    'f1350000-0000-0000-0000-000000000003',
    'f1350000-0000-0000-0000-000000000002', 'fixture-secret')$$,
  '42501', 'Dispositivo POS no autorizado',
  'cross-tenant device use is rejected'
);
SELECT ok(
  has_function_privilege(
    'anon', 'public.pos_pull_operational_catalog(uuid,uuid,text)', 'EXECUTE'
  ),
  'public endpoint remains callable with device-scoped credentials'
);

SELECT * FROM finish();
ROLLBACK;
