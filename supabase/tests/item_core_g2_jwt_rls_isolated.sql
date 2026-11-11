-- G2 isolated JWT/RLS contract. Disposable PostgreSQL 16 only.
-- This is not a migration and never targets Supabase production.
BEGIN;

CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;

CREATE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

CREATE FUNCTION auth.restaurant_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claims', true)::jsonb->>'restaurant_id', '')::uuid
$$;

CREATE FUNCTION auth.has_permission(text) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    (current_setting('request.jwt.claims', true)::jsonb->'permissions') @> to_jsonb(ARRAY[$1]),
    false
  )
$$;

CREATE TABLE public.item_core_g2_rls_probe(
  id uuid PRIMARY KEY,
  restaurant_id uuid NOT NULL,
  item_code text NOT NULL,
  created_by uuid NOT NULL
);
ALTER TABLE public.item_core_g2_rls_probe ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_core_g2_rls_probe FORCE ROW LEVEL SECURITY;
GRANT SELECT, INSERT ON public.item_core_g2_rls_probe TO authenticated;

CREATE POLICY item_core_g2_read ON public.item_core_g2_rls_probe
  FOR SELECT TO authenticated
  USING (
    restaurant_id = auth.restaurant_id()
    AND auth.has_permission('item_core.read')
  );
CREATE POLICY item_core_g2_insert ON public.item_core_g2_rls_probe
  FOR INSERT TO authenticated
  WITH CHECK (
    restaurant_id = auth.restaurant_id()
    AND created_by = auth.uid()
    AND auth.has_permission('item_core.write')
  );

INSERT INTO public.item_core_g2_rls_probe VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   '11111111-1111-4111-8111-111111111111', 'TENANT-A',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '22222222-2222-4222-8222-222222222222', 'TENANT-B',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb01');

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01', true);
SELECT set_config('request.jwt.claims',
  '{"restaurant_id":"11111111-1111-4111-8111-111111111111",'
  '"permissions":["item_core.read","item_core.write"]}', true);

DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.item_core_g2_rls_probe;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'tenant_or_read_permission_bypass: %', v_count;
  END IF;

  INSERT INTO public.item_core_g2_rls_probe VALUES (
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    '11111111-1111-4111-8111-111111111111', 'TENANT-A-NEW',
    auth.uid()
  );

  PERFORM set_config('request.jwt.claims',
    '{"restaurant_id":"11111111-1111-4111-8111-111111111111",'
    '"permissions":[]}', true);
  SELECT count(*) INTO v_count
  FROM public.item_core_g2_rls_probe;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'revoked_read_permission_remained_effective: %', v_count;
  END IF;

  BEGIN
    INSERT INTO public.item_core_g2_rls_probe VALUES (
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      '11111111-1111-4111-8111-111111111111', 'WRITE-DENIED', auth.uid()
    );
    RAISE EXCEPTION 'revoked_write_permission_remained_effective';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  RAISE NOTICE 'PASS G2 JWT/RLS: tenant isolation, permission grant and immediate revocation';
END $$;

RESET ROLE;
ROLLBACK;
