# FE-E4 — Corrección de permisos REST/RLS para catálogos de Empaques

**Fecha:** 2026-11-07. **Estado:** propuesta implementada en GitHub, pendiente de validación SQL/Auth en Docker; no aplicar a producción.  
**Origen:** `feature/packaging-backoffice-destinations` @ `76ecd423d9d6f85eafebe8190c62ae308b1f6990`.  
**Cambio:** `supabase/migrations/085_scope_packaging_catalog_writes_by_permission.sql`.

## Causa verificada
La migración 009 creó políticas `FOR ALL TO authenticated` para `sales_types`, `packaging_items` y `product_packaging_rules` con único control `is_same_restaurant`. La nueva interfaz limita navegación, pero un usuario Auth del mismo restaurante puede usar REST contra una tabla que no debería administrar.

## Cambio de seguridad
- Las tres tablas conservan **SELECT por restaurante** para que el POS/sincronización siga consultando el catálogo.
- Las operaciones INSERT, UPDATE y DELETE exigen permiso explícito del usuario Backoffice activo, perfil del mismo restaurante y `auth.uid()`, mediante `app_can_manage_packaging_catalog` (SQL SECURITY DEFINER con búsqueda controlada y acceso limitado).
- `sales_types` exige `tipos_venta.gestionar`; `packaging_items` y `product_packaging_rules` exigen `empaques.gestionar`.
- Se eliminan políticas `FOR ALL` anteriores, reemplazándolas por cuatro políticas de acceso por tabla. No cambian tablas, UUID, catálogo, stock, movimientos ni cadena POS RPC.

## Pruebas obligatorias en laboratorio (84 migraciones existentes)
1. Inspeccionar con `pg_policies` todas las políticas efectivas **antes/después** de migración 085; si existen otras políticas permisivas de escritura no contempladas, corregir y registrar.
2. Aplicar 085 **solo local** sin `db reset`, comprobar 85/85.
3. Crear dos actores Auth sintéticos, misma empresa y rol distinto: solo `tipos_venta.gestionar` y solo `empaques.gestionar`. Un tercero sin permisos y uno de restaurante distinto.
4. Test HTTP auténtico con JWT de cada usuario (no `service_role`) sobre **GET, POST, PATCH y DELETE** de cada catálogo; esperar SELECT del mismo restaurante autorizado para operación POS, escritura únicamente del permiso concreto; verificar ausencia de cambio físico y no solo código HTTP (PostgREST puede responder 204 con cero filas afectadas).
5. Probar `INSERT` de regla referenciando producto/tipo/empaque de otro restaurante: detectar si FK no impide vínculos cross-tenant. Si ocurre, bloquear despliegue y diseñar trigger de validación/constraint, no asumir seguridad por RLS.
6. Probar suplantación de `restaurant_id`, ausencia de sesión, usuario Auth sin perfil, perfil inactivo y rol revocado.
7. Confirmar admin legítimo CRUD y catalog pull POS, compra por lote, movimientos, venta, anulación, reenvío, inventario; no modificar permisos de RPC operativos usados por POS.
8. **Superficie RPC adicional:** `ensure_default_sales_types(uuid)` y `apply_packaging_movement(...)` son `SECURITY DEFINER` con `GRANT EXECUTE TO authenticated` y solo verifican restaurante. Evaluar bypass de escrituras por invocación directa y endurecer mediante autorización apropiada sin interrumpir integraciones; el cambio RLS por sí solo no protege SECURITY DEFINER.
9. Detectar el efecto del `/packaging` antiguo con permiso OR: aún muestra editores cruzados. Necesita cierre UX, no considerar terminado solo con RLS.
10. Ejecutar `flutter analyze` y pruebas Flutter de navegación, Backoffice, Ventas, Inventario, Sync; documentar resultados exactos.

## Gate
**G-RLS pendiente**: migración versionada, sin ejecución ni pruebas de roles parciales. No fusionar ni desplegar hasta confirmar seguridad real y reparar bypasses RPC, incluidas las rutas antiguas.

## Validación local y remediación — 2026-11-07

### Entorno

- Worktree independiente en `fix/packaging-catalog-rls`; `main`, sus 17 stashes
  y los demás worktrees no se modificaron.
- Docker/Supabase local conserva bindings exclusivos en `127.0.0.1:54321`
  (API/Kong) y `127.0.0.1:54324` (PostgreSQL). No se usaron enlaces,
  credenciales ni endpoints de producción.
- Se aplicaron 085, 086 y 087 sólo al laboratorio, sin `db reset`: **87/87**
  migraciones registradas.

### Hallazgo de 085 y corrección

La primera prueba REST del administrador completo contra 085 devolvió HTTP 500,
`54001 stack depth limit exceeded`. La causa fue la recursión de RLS de
`profiles`: `app_can_manage_packaging_catalog` consultaba `profiles` mientras
la política de esa tabla llamaba a `is_same_restaurant()` y
`current_restaurant_id()`.

- **086** convierte `current_restaurant_id()` en helper `SECURITY DEFINER` con
  `search_path` controlado y `row_security=off`, y hace que la comprobación de
  permisos consulte directamente el perfil activo del actor.
- **087** añade defensa para RPC `SECURITY DEFINER`: triggers de permiso en los
  tres catálogos, trigger de pertenencia de entidades para reglas y guardas de
  movimientos de empaques. Los usuarios POS conservan el camino operativo; los
  administradores no POS requieren el permiso correspondiente. El servicio
  confiable y el mantenimiento SQL local no se bloquean.

### Pruebas REST con JWT de usuario

Se crearon cinco usuarios Auth sintéticos locales: administrador completo,
`tipos_venta.gestionar`, `empaques.gestionar`, ninguno y otro restaurante.
Los JWT usados para las pruebas fueron los de login normal; `service_role` se
usó sólo para aprovisionar los actores sintéticos.

- Admin completo: GET/POST/PATCH/DELETE de los tres catálogos, correcto; cada
  fila sintética se verificó antes y después y se eliminó.
- Sólo `tipos_venta.gestionar`: CRUD de `sales_types` correcto; POST/PATCH/
  DELETE de empaques y reglas rechazados con HTTP 403/42501 y cero filas.
- Sólo `empaques.gestionar`: CRUD de `packaging_items` y
  `product_packaging_rules` correcto; operaciones sobre `sales_types`
  rechazadas con HTTP 403/42501 y cero filas.
- Sin permisos y otro restaurante: escrituras rechazadas con HTTP 403/42501;
  no se crearon filas. Las lecturas de un usuario del mismo restaurante
  permanecen disponibles para consumo del catálogo; el usuario de otro
  restaurante no recibe filas del restaurante de prueba.
- Una regla que vinculaba producto/empaque del restaurante de prueba con una
  modalidad de otro restaurante fue rechazada con HTTP 400/23514 y dejó cero
  filas.

### RPC

- 085 dejaba `ensure_default_sales_types` y `apply_packaging_movement` con
  `EXECUTE` para `authenticated` y control únicamente por restaurante. Eso
  permitía alcanzar funciones `SECURITY DEFINER` sin el permiso de catálogo.
- Con 087, `ensure_default_sales_types` invocado por un usuario sin permiso
  devuelve HTTP 403/42501 y el contador queda sin cambios. Un usuario POS
  conserva el caso operativo previsto.
- `apply_packaging_movement` invocado por un usuario sin permiso devuelve HTTP
  403/42501; el movimiento no se registra y el stock no cambia. No se alteró
  la lógica de ventas, sincronización, compras legítimas ni POS.

### Flutter

- `flutter test test/core/navigation -r expanded`: **8/8**.
- `flutter test test/core/design_system -r expanded`: **35/35**.
- `flutter test test/features/sales -r expanded`: **23/23**.
- `flutter test test/features/inventory -r expanded`: **7/7**.
- `flutter test test/features/sync -r expanded`: **48/48**.
- `flutter analyze`/`dart analyze` no pudieron completar en este Windows:
  después de `flutter pub get` el proceso quedó sin salida durante varios
  minutos. Se detuvieron sólo los procesos de análisis lanzados en este
  worktree; no se declarará análisis global aprobado por ese motivo.

### Estado del gate

La evidencia REST y de RPC queda corregida en el laboratorio y no mostró
escrituras no autorizadas después de 086/087. La migración 085 por sí sola no
era suficiente; el cierre requiere revisión de los cambios 086/087, ejecución
de `flutter analyze` en CI o un entorno donde finalice y revisión separada de
la ruta legacy `/packaging`, que conserva su autorización OR en la interfaz.
