# FE-E8 — Desacoplamiento de guardas de rutas administrativas y permisos POS locales

Fecha: 2026-11-08. Estado: **corrección versionada, pendiente de pruebas y QA en el navegador**.

## Evidencia visual

Con login remoto confirmado en Kivo Laboratorio, el Backoffice muestra menú y pestañas de Productos, Empaques y Usuarios, pero el contenido de Productos dice **Acceso restringido**. La pertenencia al restaurante, Auth y JWT fueron validados en Supabase.

## Causa identificada en código

- `BackofficeHomePage._loadPermissions()` obtiene códigos desde `SupabaseAdminRepository.getPermissionCodesForRole` (Supabase con JWT remoto).
- `RouteAccessGuard.build` usaba `AccessControlService.hasAnyPermission`, registrado en DI con `RolesRepository(LocalRolesDataSource(AppDatabase))`: origen **Drift POS local**.
- En el modo `SMOO_APP_MODE=backoffice` no se ejecuta inicialización/restauración POS, por lo que **no está garantizado** que los permisos locales estén presentes. Resultado: sidebar permite navegar, guardia de página devuelve denegación.
- No se debe cambiar RLS ni entregar privilegios por omisión.

## Cambio

En `RouteAccessGuard`, cuando `AppRunMode.isBackoffice`, se consulta `SupabaseAdminRepository.getPermissionCodesForRole(roleId)`, calculando la intersección con permisos exigidos para esa ruta. Si el origen remoto falla, se mantiene denegación (fail closed). El modo POS `standard` conserva `AccessControlService` con permisos locales. El bypass admin ya existente por ID local `role-admin` no se amplía.

## Validación obligatoria de Codex

1. Sincronizar rama y comprobar SHA, no perder 17 stashes ni las localizaciones sin commit.
2. Ejecutar formateo, pruebas unitarias/widget de guardas: Backoffice con solo `productos.gestionar` puede abrir Productos pero no Empaques; solo `empaques.gestionar` puede abrir Empaques pero no Productos; sin permisos y fallo de consulta permanecen denegados. Verificar admin, rol revocado y registro `role-admin` sin abusar de suposición de rol; POS standard sigue consultando solo Drift. Agregar pruebas que inyecten origen remoto sin depender del servidor si hace falta.
3. Probar realmente login sintético y abrir Inicio, Productos, Empaques, Usuarios mediante Chrome local 8092 con JWT y servidor Supabase 87/87. No declarar validación visual si no hay navegador; solicitar prueba al usuario.
4. Recompilar 8092 desde `fix/backoffice-remote-route-permissions` con `SMOO_APP_MODE=backoffice`, preservando defines exclusivamente locales en memoria, sin credenciales en commits/logs.
5. Ejecutar pruebas de auth, route guards, navegación, Backoffice, Productos y módulo Empaques, y registrar `flutter analyze` si retorna o continúa bloqueado.
6. Verificar que REST/RPC RLS y políticas 085-087 permanecen intactas. No hay cambios SQL previstos.
7. Inspeccionar además que `RoleAccessGuard` no permita asumir identidades admin por campos manipulables y que el backend sigue siendo autoridad final. Registrar riesgos no resueltos.

No fusionar PR ni despliegues; producción, `main`, Tentrix y otros worktrees fuera de alcance.
