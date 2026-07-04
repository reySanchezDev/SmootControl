DROP POLICY IF EXISTS roles_write_same_restaurant ON public.roles;
CREATE POLICY roles_write_same_restaurant
  ON public.roles
  FOR ALL TO authenticated
  USING (restaurant_id IS NULL OR public.is_same_restaurant(restaurant_id))
  WITH CHECK (public.is_same_restaurant(restaurant_id));

DROP POLICY IF EXISTS role_permissions_write_same_restaurant
  ON public.role_permissions;
CREATE POLICY role_permissions_write_same_restaurant
  ON public.role_permissions
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.roles role
      WHERE role.id = role_id
        AND (role.restaurant_id IS NULL OR public.is_same_restaurant(role.restaurant_id))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.roles role
      WHERE role.id = role_id
        AND (role.restaurant_id IS NULL OR public.is_same_restaurant(role.restaurant_id))
    )
  );

COMMENT ON POLICY roles_write_same_restaurant ON public.roles IS
  'Allows an authenticated restaurant administrator to claim/update base roles into the restaurant scope.';

COMMENT ON POLICY role_permissions_write_same_restaurant ON public.role_permissions IS
  'Allows replacing permissions for base or restaurant-scoped roles visible to the authenticated restaurant.';
