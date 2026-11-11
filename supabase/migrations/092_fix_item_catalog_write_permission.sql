-- Corrective migration for the already-installed 089 writer guard.
-- Never rewrite 089: product catalog writers need productos.gestionar, while
-- the legacy packaging helper intentionally accepts only packaging scopes.
BEGIN;

CREATE OR REPLACE FUNCTION item_core_internal.assert_catalog_write(
  p_restaurant_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.profiles actor
    JOIN public.role_permissions grant_row ON grant_row.role_id = actor.role_id
    JOIN public.permissions permission ON permission.id = grant_row.permission_id
    WHERE actor.id = auth.uid()
      AND actor.restaurant_id = p_restaurant_id
      AND actor.is_active = true
      AND actor.is_pos_user = false
      AND permission.code IN (
        'productos.gestionar', 'empaques.gestionar', 'tipos_venta.gestionar'
      )
  ) THEN
    RAISE EXCEPTION 'item_catalog_write_not_authorized' USING ERRCODE = '42501';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION item_core_internal.assert_catalog_write(uuid)
  FROM PUBLIC, anon, authenticated;

COMMIT;
