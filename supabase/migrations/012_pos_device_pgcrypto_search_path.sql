CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.register_pos_device(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  has_permission boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Usuario remoto requerido para registrar dispositivo'
      USING ERRCODE = '42501';
  END IF;

  SELECT EXISTS (
    SELECT 1
      FROM public.profiles profile
      JOIN public.role_permissions role_permission
        ON role_permission.role_id = profile.role_id
      JOIN public.permissions permission
        ON permission.id = role_permission.permission_id
     WHERE profile.id = auth.uid()
       AND profile.restaurant_id = p_restaurant_id
       AND profile.is_active = true
       AND permission.code = 'dispositivo.inicializar'
  )
    INTO has_permission;

  IF NOT has_permission THEN
    RAISE EXCEPTION 'No autorizado para registrar dispositivo POS'
      USING ERRCODE = '42501';
  END IF;

  IF p_device_secret IS NULL OR length(btrim(p_device_secret)) < 32 THEN
    RAISE EXCEPTION 'Credencial de dispositivo invalida'
      USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.pos_devices (
    id,
    restaurant_id,
    name,
    secret_hash,
    is_active,
    created_by_user_id,
    created_at,
    updated_at
  )
  VALUES (
    p_device_id,
    p_restaurant_id,
    p_name,
    encode(extensions.digest(p_device_secret, 'sha256'), 'hex'),
    true,
    auth.uid(),
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE
     SET restaurant_id = excluded.restaurant_id,
         name = excluded.name,
         secret_hash = excluded.secret_hash,
         is_active = true,
         updated_at = now();

  RETURN p_device_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_pos_device(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_device_secret text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM public.pos_devices
     WHERE id = p_device_id
       AND restaurant_id = p_restaurant_id
       AND is_active = true
       AND secret_hash = encode(extensions.digest(p_device_secret, 'sha256'), 'hex')
  ) THEN
    RAISE EXCEPTION 'Dispositivo POS no autorizado'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.pos_devices
     SET last_seen_at = now(),
         updated_at = now()
   WHERE id = p_device_id
     AND restaurant_id = p_restaurant_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.register_pos_device(uuid, uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.assert_pos_device(uuid, uuid, text)
  TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
