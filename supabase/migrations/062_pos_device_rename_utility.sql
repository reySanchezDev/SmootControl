CREATE OR REPLACE FUNCTION public.app_rename_pos_device(
  p_restaurant_id uuid,
  p_device_id uuid,
  p_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  clean_name text := trim(p_name);
BEGIN
  PERFORM public.app_assert_admin_permission(
    p_restaurant_id,
    'sistema.reiniciar_operacion'
  );

  IF clean_name IS NULL OR length(clean_name) < 2 THEN
    RAISE EXCEPTION 'Nombre de dispositivo invalido'
      USING ERRCODE = '23514';
  END IF;

  IF length(clean_name) > 80 THEN
    clean_name := substring(clean_name from 1 for 80);
  END IF;

  UPDATE public.pos_devices
  SET name = clean_name,
      updated_at = now()
  WHERE id = p_device_id
    AND restaurant_id = p_restaurant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Dispositivo POS no encontrado'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.audit_logs (
    restaurant_id,
    actor_user_id,
    action,
    entity_name,
    entity_id,
    details
  )
  VALUES (
    p_restaurant_id,
    auth.uid(),
    'system.rename_pos_device',
    'pos_devices',
    p_device_id,
    jsonb_build_object('name', clean_name)
  );

  RETURN jsonb_build_object(
    'device_id', p_device_id,
    'name', clean_name
  );
END;
$$;

REVOKE ALL ON FUNCTION public.app_rename_pos_device(uuid, uuid, text)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.app_rename_pos_device(uuid, uuid, text)
  TO authenticated;
