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
## Validación Codex — 2026-11-08

- Se validó el worktree independiente de `fix/backoffice-remote-route-permissions`, preservando el worktree principal y sus 17 stashes.
- `RouteAccessGuard` consulta Supabase en modo Backoffice y conserva `AccessControlService` sobre Drift en POS estándar. El error remoto permanece fail-closed; no se modificaron RLS, SQL ni migraciones.
- Se agregó `test/core/navigation/route_access_guard_test.dart` con HTTP simulado: administrador, permiso parcial, ausencia de permiso y fallo remoto pasan 4/4 bajo `SMOO_APP_MODE=backoffice`.
- Pasaron las pruebas focalizadas de autenticación, inicialización, navegación, workspace/sidebar, rutas de empaques, productos, reglas de empaques y permisos locales POS. Total registrado: 47 pruebas.
- `dart format` no modificó el código existente y formateó la nueva prueba. `flutter analyze --no-pub` quedó inconcluso en `Analyzing ...` sin diagnóstico ni código de salida; se interrumpió de forma controlada.
- Supabase Docker respondió HTTP 200; PostgreSQL y API permanecen en `127.0.0.1:54324` y `127.0.0.1:54321`. La base local reportó 87 migraciones aplicadas, última `087`.
- Se reconstruyó el preview de esta rama en `http://127.0.0.1:8092/` con configuración sintética en memoria. HTTP 200 y bootstrap Flutter fueron comprobados. No hubo navegador controlable disponible; Inicio, Productos, Empaques y Usuarios quedan pendientes de QA visual manual.
