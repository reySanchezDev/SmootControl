-- Administrative writes used by the APK/web admin surfaces.
-- These RPCs make access-control changes explicit, permission-checked and
-- transactional instead of relying on generic PostgREST upserts.

CREATE OR REPLACE FUNCTION public.app_assert_admin_permission(
  p_restaurant_id uuid,
  p_permission_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor_id uuid := auth.uid();
BEGIN
  IF actor_id IS NULL THEN
    RAISE EXCEPTION 'Se requiere sesion administrativa remota'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.is_same_restaurant(p_restaurant_id) THEN
    RAISE EXCEPTION 'No autorizado para este restaurante'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM public.profiles profile
      JOIN public.role_permissions role_permission
        ON role_permission.role_id = profile.role_id
      JOIN public.permissions permission
        ON permission.id = role_permission.permission_id
     WHERE profile.id = actor_id
       AND profile.restaurant_id = p_restaurant_id
       AND profile.is_active = true
       AND permission.code = p_permission_code
  ) THEN
    RAISE EXCEPTION 'No autorizado para administrar: %', p_permission_code
      USING ERRCODE = '42501';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.app_upsert_permission(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  permission_code text;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'roles.gestionar'
  );

  permission_code := NULLIF(btrim(p_payload ->> 'code'), '');
  IF permission_code IS NULL THEN
    RAISE EXCEPTION 'Permiso sin codigo'
      USING ERRCODE = '23502';
  END IF;

  INSERT INTO public.permissions (
    code,
    name,
    description
  )
  VALUES (
    permission_code,
    COALESCE(NULLIF(btrim(p_payload ->> 'name'), ''), permission_code),
    NULLIF(p_payload ->> 'description', '')
  )
  ON CONFLICT (code) DO UPDATE
     SET name = excluded.name,
         description = excluded.description;

  RETURN jsonb_build_object('code', permission_code);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_upsert_role(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  role_id text;
  role_code text;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'roles.gestionar'
  );

  role_id := NULLIF(btrim(p_payload ->> 'id'), '');
  IF role_id IS NULL THEN
    RAISE EXCEPTION 'Rol sin id'
      USING ERRCODE = '23502';
  END IF;

  role_code := COALESCE(
    NULLIF(btrim(p_payload ->> 'code'), ''),
    role_id
  );

  INSERT INTO public.roles (
    id,
    restaurant_id,
    code,
    name,
    description,
    is_system,
    is_active,
    updated_at
  )
  VALUES (
    role_id,
    p_restaurant_id,
    role_code,
    COALESCE(NULLIF(btrim(p_payload ->> 'name'), ''), role_code),
    NULLIF(p_payload ->> 'description', ''),
    COALESCE((p_payload ->> 'is_system')::boolean, false),
    COALESCE((p_payload ->> 'is_active')::boolean, true),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET restaurant_id = COALESCE(public.roles.restaurant_id, excluded.restaurant_id),
         code = excluded.code,
         name = excluded.name,
         description = excluded.description,
         is_system = excluded.is_system,
         is_active = excluded.is_active,
         updated_at = now();

  RETURN jsonb_build_object('id', role_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_replace_role_permissions(
  p_restaurant_id uuid,
  p_role_id text,
  p_permission_codes text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  missing_codes text[];
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'roles.gestionar'
  );

  IF NOT EXISTS (
    SELECT 1
      FROM public.roles role
     WHERE role.id = p_role_id
       AND (
         role.restaurant_id = p_restaurant_id
         OR role.restaurant_id IS NULL
       )
  ) THEN
    RAISE EXCEPTION 'Rol remoto no encontrado: %', p_role_id
      USING ERRCODE = '23503';
  END IF;

  SELECT array_agg(code)
    INTO missing_codes
    FROM unnest(COALESCE(p_permission_codes, ARRAY[]::text[])) AS code
   WHERE NOT EXISTS (
     SELECT 1
       FROM public.permissions permission
      WHERE permission.code = code
   );

  IF missing_codes IS NOT NULL THEN
    RAISE EXCEPTION 'Permisos remotos no encontrados: %',
      array_to_string(missing_codes, ', ')
      USING ERRCODE = '23503';
  END IF;

  UPDATE public.roles
     SET restaurant_id = p_restaurant_id,
         updated_at = now()
   WHERE id = p_role_id
     AND restaurant_id IS NULL;

  DELETE FROM public.role_permissions
   WHERE role_id = p_role_id;

  INSERT INTO public.role_permissions (
    role_id,
    permission_id
  )
  SELECT p_role_id,
         permission.id
    FROM public.permissions permission
   WHERE permission.code = ANY(COALESCE(p_permission_codes, ARRAY[]::text[]))
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object(
    'role_id', p_role_id,
    'permission_count', COALESCE(array_length(p_permission_codes, 1), 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.app_upsert_profile(
  p_restaurant_id uuid,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  profile_id uuid;
  profile_role_id text;
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'usuarios.gestionar'
  );

  profile_id := (p_payload ->> 'id')::uuid;
  profile_role_id := NULLIF(btrim(p_payload ->> 'role_id'), '');

  IF profile_role_id IS NULL THEN
    RAISE EXCEPTION 'Usuario sin rol'
      USING ERRCODE = '23502';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM public.roles role
     WHERE role.id = profile_role_id
       AND (
         role.restaurant_id = p_restaurant_id
         OR role.restaurant_id IS NULL
       )
  ) THEN
    RAISE EXCEPTION 'Rol remoto no encontrado para usuario: %',
      profile_role_id
      USING ERRCODE = '23503';
  END IF;

  INSERT INTO public.profiles (
    id,
    restaurant_id,
    role_id,
    display_name,
    email,
    is_active,
    is_pos_user,
    pin_salt,
    pin_hash,
    updated_at
  )
  VALUES (
    profile_id,
    p_restaurant_id,
    profile_role_id,
    COALESCE(NULLIF(btrim(p_payload ->> 'display_name'), ''), 'Usuario'),
    lower(COALESCE(NULLIF(btrim(p_payload ->> 'email'), ''), profile_id::text)),
    COALESCE((p_payload ->> 'is_active')::boolean, true),
    COALESCE((p_payload ->> 'is_pos_user')::boolean, false),
    NULLIF(p_payload ->> 'pin_salt', ''),
    NULLIF(p_payload ->> 'pin_hash', ''),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET restaurant_id = excluded.restaurant_id,
         role_id = excluded.role_id,
         display_name = excluded.display_name,
         email = excluded.email,
         is_active = excluded.is_active,
         is_pos_user = excluded.is_pos_user,
         pin_salt = COALESCE(excluded.pin_salt, public.profiles.pin_salt),
         pin_hash = COALESCE(excluded.pin_hash, public.profiles.pin_hash),
         updated_at = now();

  RETURN jsonb_build_object('id', profile_id);
END;
$$;

REVOKE ALL ON FUNCTION public.app_assert_admin_permission(uuid, text)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_upsert_permission(uuid, jsonb)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_upsert_role(uuid, jsonb)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_replace_role_permissions(uuid, text, text[])
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_upsert_profile(uuid, jsonb)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_assert_admin_permission(uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_upsert_permission(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_upsert_role(uuid, jsonb)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_replace_role_permissions(uuid, text, text[])
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_upsert_profile(uuid, jsonb)
  TO authenticated;
