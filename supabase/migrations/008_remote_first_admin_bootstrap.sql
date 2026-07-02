CREATE OR REPLACE FUNCTION public.bootstrap_status(p_restaurant_id uuid)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'restaurant_id', p_restaurant_id,
    'profile_count', (
      SELECT count(*)
      FROM public.profiles
      WHERE restaurant_id = p_restaurant_id
    ),
    'has_profiles', EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE restaurant_id = p_restaurant_id
    )
  )
$$;

CREATE OR REPLACE FUNCTION public.bootstrap_first_admin(
  p_restaurant_id uuid,
  p_email text,
  p_display_name text,
  p_pin_salt text,
  p_pin_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE restaurant_id = p_restaurant_id
  ) THEN
    RAISE EXCEPTION 'El administrador inicial ya fue creado.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT id
  INTO v_user_id
  FROM auth.users
  WHERE lower(email) = lower(trim(p_email))
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Primero debe existir el usuario Auth remoto.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE auth.users
  SET email_confirmed_at = coalesce(email_confirmed_at, now()),
      raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
      updated_at = now()
  WHERE id = v_user_id;

  INSERT INTO public.restaurants (
    id,
    commercial_name,
    legal_name,
    email,
    created_at,
    updated_at
  )
  VALUES (
    p_restaurant_id,
    'SmooControl',
    'SmooControl',
    lower(trim(p_email)),
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE
  SET email = excluded.email,
      updated_at = now();

  INSERT INTO public.invoice_number_settings (
    restaurant_id,
    prefix,
    initial_number,
    next_number,
    created_at,
    updated_at
  )
  VALUES (p_restaurant_id, 'F-', 1, 1, now(), now())
  ON CONFLICT (restaurant_id) DO NOTHING;

  INSERT INTO public.permissions (code, name)
  VALUES
    ('usuarios.gestionar', 'Gestionar usuarios'),
    ('roles.gestionar', 'Gestionar roles'),
    ('mesas.gestionar', 'Gestionar mesas'),
    ('productos.gestionar', 'Gestionar productos'),
    ('inventario.gestionar', 'Gestionar inventario'),
    ('modificadores.gestionar', 'Gestionar modificadores POS'),
    ('ventas.registrar', 'Registrar ventas'),
    ('caja.aperturar', 'Aperturar caja'),
    ('caja.cerrar', 'Cerrar caja'),
    ('gastos.categorias.gestionar', 'Gestionar categorias de gastos'),
    ('gastos.registrar', 'Registrar gastos operativos'),
    ('pdf.generar', 'Generar PDF'),
    ('pagos.gestionar', 'Gestionar metodos de pago'),
    ('cuentas.separar', 'Separar cuentas'),
    ('ventas.anular', 'Anular ventas'),
    ('reportes.ver', 'Ver reportes'),
    ('configuracion.gestionar', 'Gestionar configuracion'),
    ('tasas.gestionar', 'Gestionar tasas de cambio'),
    ('auditoria.ver', 'Ver auditoria'),
    ('sync.configurar', 'Configurar sincronizacion'),
    ('sync.ejecutar', 'Ejecutar sincronizacion manual'),
    ('dispositivo.inicializar', 'Inicializar dispositivo')
  ON CONFLICT (code) DO NOTHING;

  INSERT INTO public.roles (
    id,
    restaurant_id,
    code,
    name,
    is_system,
    is_active,
    created_at,
    updated_at
  )
  VALUES
    ('role-admin', NULL, 'admin', 'Administrador', true, true, now(), now()),
    ('role-cashier', NULL, 'cashier', 'Cajero', true, true, now(), now()),
    ('role-waiter', NULL, 'waiter', 'Mesero', true, true, now(), now())
  ON CONFLICT DO NOTHING;

  INSERT INTO public.role_permissions (role_id, permission_id)
  SELECT 'role-admin', id
  FROM public.permissions
  ON CONFLICT DO NOTHING;

  INSERT INTO public.role_permissions (role_id, permission_id)
  SELECT 'role-cashier', id
  FROM public.permissions
  WHERE code IN (
    'ventas.registrar',
    'caja.aperturar',
    'caja.cerrar',
    'pdf.generar',
    'cuentas.separar',
    'ventas.anular',
    'sync.ejecutar'
  )
  ON CONFLICT DO NOTHING;

  INSERT INTO public.role_permissions (role_id, permission_id)
  SELECT 'role-waiter', id
  FROM public.permissions
  WHERE code IN (
    'ventas.registrar',
    'cuentas.separar',
    'sync.ejecutar'
  )
  ON CONFLICT DO NOTHING;

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
    created_at,
    updated_at
  )
  VALUES (
    v_user_id,
    p_restaurant_id,
    'role-admin',
    trim(p_display_name),
    lower(trim(p_email)),
    true,
    false,
    p_pin_salt,
    p_pin_hash,
    now(),
    now()
  );

  INSERT INTO public.payment_methods (
    code,
    name,
    group_name,
    currency_code,
    requires_reference,
    affects_cash,
    display_order,
    is_payment_target,
    is_active,
    created_at,
    updated_at
  )
  VALUES
    ('payment_cash', 'Efectivo', 'Efectivo', null, false, false, 0, false, true, now(), now()),
    ('payment_transfer', 'Transferencias', 'Transferencias', null, false, false, 10, false, true, now(), now()),
    ('payment_card', 'Tarjeta', 'Tarjeta', null, false, false, 20, false, true, now(), now()),
    ('other', 'Otro', 'Otros', null, false, false, 30, true, true, now(), now())
  ON CONFLICT DO NOTHING;

  INSERT INTO public.payment_methods (
    code,
    name,
    parent_id,
    group_name,
    currency_code,
    requires_reference,
    affects_cash,
    display_order,
    is_payment_target,
    is_active,
    created_at,
    updated_at
  )
  VALUES
    ('cash_nio', 'Cordoba', (SELECT id FROM public.payment_methods WHERE code = 'payment_cash'), 'Efectivo', 'NIO', false, true, 10, true, true, now(), now()),
    ('cash_usd', 'Dolar', (SELECT id FROM public.payment_methods WHERE code = 'payment_cash'), 'Efectivo', 'USD', false, true, 20, true, true, now(), now()),
    ('transfer_banpro', 'BANPRO', (SELECT id FROM public.payment_methods WHERE code = 'payment_transfer'), 'Transferencias', null, false, false, 10, false, true, now(), now()),
    ('card_default', 'POS Tarjeta', (SELECT id FROM public.payment_methods WHERE code = 'payment_card'), 'Tarjeta', null, true, false, 10, true, true, now(), now()),
    ('transfer_banpro_nio', 'Cuenta BANPRO NIO', (SELECT id FROM public.payment_methods WHERE code = 'transfer_banpro'), 'Transferencias', 'NIO', true, false, 10, true, true, now(), now())
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object(
    'user_id', v_user_id,
    'restaurant_id', p_restaurant_id,
    'profile_created', true
  );
END;
$$;

REVOKE ALL ON FUNCTION public.bootstrap_status(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.bootstrap_first_admin(uuid, text, text, text, text)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.bootstrap_status(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_first_admin(
  uuid,
  text,
  text,
  text,
  text
) TO anon, authenticated;
