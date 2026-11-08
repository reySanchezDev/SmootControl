-- Avoid recursive profiles RLS evaluation while checking catalog permissions.
-- The helper only returns the authenticated user's active restaurant.
CREATE OR REPLACE FUNCTION public.current_restaurant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
  SELECT restaurant_id
  FROM public.profiles
  WHERE id = auth.uid()
    AND is_active = true
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.current_restaurant_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_restaurant_id() TO authenticated;

-- Do not call is_same_restaurant from this permission policy. Its normal
-- invoker path can re-enter profiles RLS. The profile lookup below is made by
-- this SECURITY DEFINER function with row security disabled, while still
-- requiring the same restaurant, active non-POS actor and exact permission.
CREATE OR REPLACE FUNCTION public.app_can_manage_packaging_catalog(
  p_restaurant_id uuid,
  p_permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
  SELECT auth.uid() IS NOT NULL
    AND p_permission_code IN (
      'tipos_venta.gestionar', 'empaques.gestionar'
    )
    AND EXISTS (
      SELECT 1
      FROM public.profiles AS actor
      JOIN public.role_permissions AS grant_row
        ON grant_row.role_id = actor.role_id
      JOIN public.permissions AS permission
        ON permission.id = grant_row.permission_id
      WHERE actor.id = auth.uid()
        AND actor.restaurant_id = p_restaurant_id
        AND actor.is_active = true
        AND actor.is_pos_user = false
        AND permission.code = p_permission_code
    );
$$;

REVOKE ALL ON FUNCTION public.app_can_manage_packaging_catalog(uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_can_manage_packaging_catalog(uuid, text)
  TO authenticated;
