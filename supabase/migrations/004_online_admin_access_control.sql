ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_id_fkey;

ALTER TABLE public.role_permissions
  DROP CONSTRAINT IF EXISTS role_permissions_role_id_fkey;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_id_fkey;

ALTER TABLE public.roles
  ALTER COLUMN id DROP DEFAULT,
  ALTER COLUMN id TYPE text USING id::text,
  ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE public.role_permissions
  ALTER COLUMN role_id TYPE text USING role_id::text;

ALTER TABLE public.profiles
  ALTER COLUMN role_id TYPE text USING role_id::text;

ALTER TABLE public.role_permissions
  ADD CONSTRAINT role_permissions_role_id_fkey
  FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_id_fkey
  FOREIGN KEY (role_id) REFERENCES public.roles(id);

DROP POLICY IF EXISTS roles_write_same_restaurant ON public.roles;
CREATE POLICY roles_write_same_restaurant
  ON public.roles
  FOR ALL TO authenticated
  USING (public.is_same_restaurant(restaurant_id))
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
        AND public.is_same_restaurant(role.restaurant_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.roles role
      WHERE role.id = role_id
        AND public.is_same_restaurant(role.restaurant_id)
    )
  );

COMMENT ON COLUMN public.roles.id IS
  'Identificador de rol. Puede ser UUID o codigo estable local como role-admin.';

COMMENT ON COLUMN public.profiles.id IS
  'Identificador de perfil operativo. No requiere fila en auth.users.';
