# AUD-2026-11-06-004 — Backend Kivo: estado real de terminales POS y expansión de Sales Types

**Fecha:** 2026-11-06. **Tipo:** auditoría estática de backend, migraciones y consumidores críticos. **Rama de código examinada:** `develop/backoffice-stabilization-integration`, commit `7ce5163e0c6e698397dca0f57689966a4b714649`. **Documentación objetivo:** rama `main`. **Estado:** diagnóstico completo del circuito principal; verificación de esquema desplegado y ejecución de pruebas pendientes. **Sin implementación.**

## Respuesta ejecutiva

**Kivo SÍ tiene dispositivos POS persistentes**, pero **NO tiene todavía el modelo de terminal operativo configurable** que requiere la propuesta: múltiples Sales Types por terminal, predeterminado del terminal, jerarquía por sucursal, perfil de funcionalidades y gestión administrativa integral. Es preferible **evolucionar `public.pos_devices` y su identidad UUID existente**, no introducir una segunda identidad técnica de terminal que duplique registros e historial.

## Hechos comprobados en archivos de código (no en producción)

| Capacidad | Estado y evidencia |
|---|---|
| Dispositivo remoto | **Existe** `public.pos_devices` en `supabase/migrations/010_pos_device_sync.sql`: `id`, `restaurant_id`, `name`, `secret_hash`, `is_active`, creador, última actividad y timestamps |
| Registro/autenticación de dispositivo | **Existe** RPC `register_pos_device`, `assert_pos_device`; autorización por `dispositivo.inicializar`, hash SHA-256 de secreto y chequeo de `is_active` (010) |
| Inicialización local | **Existe** UUID/secret generado, registro remoto y `LocalDeviceState` con `deviceId`/`syncDeviceId`/`syncDeviceSecret`: `device_initialization_local_support.dart`, `tables/device_state_tables.dart` |
| Identidad en operaciones | **Existe** `pos_device_id` en `sales`, `cash_register_sessions`, `operating_expenses`, `inventory_movements`, `packaging_movements` y adelantos: migración 056 |
| Caja por dispositivo | **Existe** scope remoto y local: 064/065; `local_cash_register_datasource.dart` y `cash_register_repository.dart` |
| Renombrar dispositivos | **Existe** `app_rename_pos_device` en migración 062, con evento de auditoría |
| Inventario y limpieza de pruebas por dispositivo | **Existen** RPC `app_list_pos_devices_for_cleanup` y `app_cleanup_pos_device_test_data` en 061; **NO son API general de administración de terminales** |
| Catálogo de modalidades | **Existe** `sales_types` por restaurante con `is_default` global y `is_active`: 009, `LocalSalesTypes` |
| POS con múltiples modalidades visibles | **Existe parcialmente**: `pos_ticket_sales_type_controls.dart` genera chip por *todos* los tipos activos locales; no aplica filtro de terminal |
| Default por terminal | **No existe en el esquema `pos_devices` revisado** ni en carga POS: `pos_start_handlers.dart` y `pos_ready_state_derived.dart` eligen `sales_types.is_default` general |
| Asignación N:M dispositivo-modalidad | **No observada** en tablas y migraciones revisadas: no hay `terminal_sales_types` ni resolución basada en `pos_device_id` |
| Sucursal | `restaurants` es la unidad actual de configuración en `001_initial_schema.sql`; `CurrentRestaurantService` lee `SMOO_RESTAURANT_ID`; no se identificó una entidad operativa `locations`/sucursales en el circuito examinado |
| Pull por terminal | `pos_pull_operational_catalog` (016) requiere credencial del dispositivo pero selecciona `sales_types` por **restaurante**, sin filtrarlos por UUID del dispositivo |
| Validación de modalidad por dispositivo | En el circuito POS revisado, `_handleSalesTypeSelected` persiste `salesTypeId` en orden abierta sin comprobación contra autorizados del dispositivo; no debe dependerse de chips UI |
| Desacoplamiento fuente de orden/entrega | `sales_type_id` y `sales_type_name` se persisten en venta; **falta** contrato completo `origin_channel`/fuente externa por orden para futura web, QR, app, delivery |

### Evidencia rastreable
- `supabase/migrations/010_pos_device_sync.sql` — tabla y registro de dispositivos.
- `supabase/migrations/056_pos_device_traceability.sql` — trazas por `pos_device_id`.
- `supabase/migrations/064_cash_register_sessions_are_device_scoped.sql` y `065_harden_device_scoped_cash_and_sale_sync.sql` — caja/sync y pertenencia del dispositivo.
- `supabase/migrations/061_pos_device_test_cleanup.sql` y `062_pos_device_rename_utility.sql` — inventario/gestión parcial.
- `supabase/migrations/009_sales_types_packaging.sql` — catálogo global y unicidad de predeterminado por restaurante.
- `supabase/migrations/016_pos_device_catalog_pull.sql` — pull autenticado con modalidades globales.
- `lib/features/pos/presentation/bloc/pos_start_handlers.dart` — `getSalesTypes()`, filtrado activo, `_defaultSalesTypeId`.
- `lib/features/pos/presentation/bloc/pos_ready_state_derived.dart` — fallback `isDefault` global.
- `lib/features/pos/presentation/bloc/pos_cart_handlers.dart` — selección por orden abierta.
- `lib/features/pos/presentation/widgets/pos_ticket_sales_type_controls.dart` — chips de todos los tipos activos.
- `lib/features/cash_register/data/datasources/local_cash_register_datasource.dart` — scope de caja por dispositivo.
- `lib/features/auth/domain/services/device_initialization_local_support.dart` — registro desde el POS.

## Arquitectura recomendada — evolucionar, no duplicar

1. **Reutilizar `pos_devices.id`** como identidad durable de la terminal. Ampliar su *configuración operativa* con nombre visible, código de terminal único en el restaurante/sucursal, tipo, capacidades, estado `active|suspended|retired`, asignación a sucursal, `default_sales_type_id` (o preferible default en política de configuración efectiva). Mantener clave de credencial separada de la etiqueta.
2. **Modalidades por restaurante**: conservar `sales_types` como entidad reutilizable; `is_default` actual sirve como *fallback legacy* durante compatibilidad, no como único default final.
3. **Modalidades por terminal N:M**: tabla `pos_device_sales_types(pos_device_id,sales_type_id,...)`, FK, `UNIQUE`, `restaurant_id` validado, permitido solo si modalidad activa en sucursal y negocio. No usar cadenas `A|B|C`; default debe pertenecer al conjunto autorizado y estar activo.
4. **Sucursales como expansión separada**: `locations`/sucursales más `location_sales_types`, con tenant coherente. **Fase compatible:** restaurante actual = sucursal principal virtual/inicial, sin forzar creación manual de una sucursal en el piloto.
5. **Herencia explícita**: terminal `inherit` toma modalidades de sucursal; terminal `custom` mantiene lista explícita; definir cambios de política, administración y default.
6. **Pull segmentado**: RPC o payload versionado `terminal_config` obtiene permitidos+default, `config_version`, `effective_at` y fecha de expiración para operación offline; migración Drift no destructiva de caché.
7. **Validación centralizada**: chequear modalidad tanto al cambiarla en carrito como al confirmar/registrar orden y en sync remoto. Rechazar nueva orden no autorizada según política versionada, con excepción documentada para órdenes creadas offline antes de una revocación; no perder venta legítima ni aceptar duplicados.
8. **Backoffice profesional**: Configuración → Dispositivos POS para registrar/renombrar/suspender, ver última sincronización, sucursal, default, lista múltiple de modalidades y modo de herencia; Configuración → Modalidades de servicio como catálogo reutilizable. Mostrar estados claramente, no introducir acciones ocultas tras «…».
9. **Origen de orden por separado**: `origin_channel`, `origin_source_id`, `origin_device_id`, `external_order_id`, cliente/QR cuando aplique, además de `sales_type_id`; no utilizar `APP` como modalidad si significa origen.

## Riesgos existentes antes de implementar

- `register_pos_device` en 010 contiene `ON CONFLICT (id) DO UPDATE` que **podría** reactivar o reasignar una identidad si otro administrador autorizado aporta un ID existente. Verificar endurecimiento efectivo por migraciones posteriores; considerar impedir reasignar de restaurante/identidad o reinstalar secretos sin reautorización explícita.
- La identidad actual ligada a `SMOO_RESTAURANT_ID` por configuración del cliente no es un mecanismo completo de asignación dinámica a sucursales. No confiar en valor de cliente como control de autorización.
- FKs multitenant: `sales_type_id` y `device_id` deben pertenecer al **mismo restaurante**, incluidas configuraciones y RPC `SECURITY DEFINER`. Implementar constraints compuestas o validaciones atómicas, RLS y tests cruzados.
- El `is_default` único por restaurante (009) es incompatible conceptualmente con múltiples defaults distintos por terminal si se usa como única fuente; mantenerlo como fallback legacy.
- Caja, ventas, inventario y sync dependen de IDs persistentes. **No reemplazar UUID** de dispositivos actuales ni limpiar registros para hacer el cambio de esquema.
- Compatibilidad con POS offline: perfiles de configuración y filtros deben preservarse localmente, y revocaciones/remociones tener política determinista al reconectar.
- Identificación de origen y actualizaciones de orden deben persistir snapshots y eventos inmutables, no reinterpretar ventas históricas.
- Antes de habilitar web/QR/apps debe existir autoridad de órdenes remota separada del cliente POS local; no agregar endpoints públicos sin control antispam/rate-limit y seguridad.

## Plan incremental propuesto (NO aprobado para ejecución)

**T1 — Contrato:** aprobar diferencia dispositivo/terminal, modalidad/origen, sucursal virtual, modelo N:M, default y precedencias. Revisar migraciones efectivas de Supabase, accesos, roles, API y dependencias.

**T2 — Expand backend:** migración aditiva de `pos_devices`, configuración de sucursal virtual y asociación N:M; restricciones `same-tenant`, permisos y CRUD por RPC con pruebas. Sin tocar ventas ni dispositivos.

**T3 — Distribución/caché:** `terminal_config` en RPC de pull y almacenamiento Drift; bootstrap de dispositivo antiguo hereda tipos activos y default de restaurante, manteniendo UX anterior.

**T4 — Integrar POS:** mostrar solo tipos permitidos, default del terminal, validación al seleccionar y al confirmar; actualizar reglas de empaque y retener tipo por pedido abierto. Evitar romper flujo de cuentas/mesas.

**T5 — Administración:** página de Dispositivos POS y configuración de modalidades con herencia por sucursal; observabilidad y auditoría.

**T6 — QA y rollout:** pruebas E2E para múltiples tipos, distintos defaults por terminal, revocación, terminal offline, dos cajas, cambio de modalidad, facturación/idempotencia, RLS por restaurante, reinstalación, dispositivos suspendidos y pedido web asumido por caja. Aplicación real de migraciones solo tras autorización y backup.

## Límite de esta auditoría

Se inspeccionó el árbol completo de archivos versionados y se leyó el código principal de identidad, registro, credenciales, sincronización, modalidades, caja, POS y migrações SQL relevantes. **No** se inspeccionó exhaustivamente el texto de cada una de las 83 migraciones, no se consultó la base Supabase real, no se ejecutaron tests ni compilaciones y no se validó el deployment. Otras ramas pueden contener cambios posteriores. El informe distingue lo verificado del objetivo.

## Decisión recomendada
**No crear una tabla nueva `terminals` paralela a `pos_devices` como primera opción.** Extender la capacidad de dispositivo existente, preservando UUID, credenciales y trazabilidad. Añadir relación N:M con tipos de venta y resolver default/herencia por terminal. Hacerlo por fases y con migración no destructiva.
