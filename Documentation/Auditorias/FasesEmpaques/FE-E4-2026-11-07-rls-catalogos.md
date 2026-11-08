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
