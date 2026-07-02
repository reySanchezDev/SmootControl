INSERT INTO public.permissions (code, name)
VALUES ('dispositivo.inicializar', 'Inicializar dispositivo')
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM public.roles role
JOIN public.permissions permission
  ON permission.code = 'dispositivo.inicializar'
WHERE role.code = 'admin'
ON CONFLICT DO NOTHING;
