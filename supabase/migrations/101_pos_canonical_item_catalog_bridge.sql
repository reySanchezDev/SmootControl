-- Adds the canonical item snapshot to the existing device catalog response.
-- Legacy catalog keys remain during the measured POS cutover.
BEGIN;

ALTER FUNCTION public.pos_pull_operational_catalog(uuid, uuid, text)
  RENAME TO pos_pull_operational_catalog_legacy_20261117;

CREATE OR REPLACE FUNCTION public.pos_pull_operational_catalog(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_catalog jsonb;
BEGIN
  v_catalog := public.pos_pull_operational_catalog_legacy_20261117(
    p_restaurant_id,
    p_device_id,
    p_device_secret
  );
  RETURN v_catalog || jsonb_build_object(
    'item_catalog_v2', public.pos_pull_item_catalog_v2(
      p_restaurant_id,
      p_device_id,
      p_device_secret
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_pull_operational_catalog(uuid, uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pos_pull_operational_catalog(uuid, uuid, text)
  TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.pos_pull_operational_catalog(uuid, uuid, text)
IS 'POS catalog bridge: legacy operational rows plus canonical item_catalog_v2.';

COMMIT;
