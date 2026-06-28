INSERT INTO public.permissions (code, name)
VALUES
  ('usuarios.gestionar', 'Gestionar usuarios'),
  ('roles.gestionar', 'Gestionar roles'),
  ('mesas.gestionar', 'Gestionar mesas'),
  ('productos.gestionar', 'Gestionar productos'),
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
  ('sync.configurar', 'Configurar sincronizacion')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.roles (code, name, is_system)
VALUES
  ('admin', 'Administrador', true),
  ('cashier', 'Cajero', true),
  ('waiter', 'Mesero', true)
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
CROSS JOIN public.permissions permission
WHERE role.restaurant_id IS NULL
  AND role.code = 'admin'
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
JOIN public.permissions permission
  ON permission.code IN (
    'ventas.registrar',
    'caja.aperturar',
    'caja.cerrar',
    'pdf.generar',
    'cuentas.separar',
    'ventas.anular'
  )
WHERE role.restaurant_id IS NULL
  AND role.code = 'cashier'
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
JOIN public.permissions permission
  ON permission.code IN (
    'ventas.registrar',
    'cuentas.separar'
  )
WHERE role.restaurant_id IS NULL
  AND role.code = 'waiter'
ON CONFLICT DO NOTHING;

INSERT INTO public.payment_methods (
  code,
  name,
  group_name,
  currency_code,
  requires_reference,
  affects_cash,
  display_order,
  is_payment_target
)
VALUES
  ('payment_cash', 'Efectivo', 'Efectivo', null, false, false, 0, false),
  ('payment_transfer', 'Transferencias', 'Transferencias', null, false, false, 10, false),
  ('payment_card', 'Tarjeta', 'Tarjeta', null, false, false, 20, false),
  ('other', 'Otro', 'Otros', null, false, false, 30, true)
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
  is_payment_target
)
VALUES
  ('cash_nio', 'Cordoba', (SELECT id FROM public.payment_methods WHERE code = 'payment_cash'), 'Efectivo', 'NIO', false, true, 10, true),
  ('cash_usd', 'Dolar', (SELECT id FROM public.payment_methods WHERE code = 'payment_cash'), 'Efectivo', 'USD', false, true, 20, true),
  ('transfer_banpro', 'BANPRO', (SELECT id FROM public.payment_methods WHERE code = 'payment_transfer'), 'Transferencias', null, false, false, 10, false),
  ('card_default', 'POS Tarjeta', (SELECT id FROM public.payment_methods WHERE code = 'payment_card'), 'Tarjeta', null, true, false, 10, true)
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
  is_payment_target
)
VALUES
  ('transfer_banpro_nio', 'Cuenta BANPRO NIO', (SELECT id FROM public.payment_methods WHERE code = 'transfer_banpro'), 'Transferencias', 'NIO', true, false, 10, true)
ON CONFLICT DO NOTHING;

INSERT INTO public.expense_categories (name, display_order)
VALUES
  ('Gastos varios', 10),
  ('Gastos de nomina', 20),
  ('Gastos de inventario', 30),
  ('Servicios basicos', 40),
  ('Mantenimiento', 50),
  ('Transporte', 60),
  ('Otros', 70)
ON CONFLICT DO NOTHING;
