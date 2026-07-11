# Auditoria De Estabilidad V1 Preproduccion

Fecha: 2026-07-07

## Objetivo

Blindar la V1 antes de produccion sin separar todavia BackOffice/POS. El APK
seguira incluyendo POS y Admin, pero con reglas estrictas:

- POS opera local/offline y sincroniza despues.
- Admin lee/escribe directo en Supabase.
- Sincronizacion y Utilidades son excepciones mixtas intencionales.
- No se debe pedir desinstalar si existen ventas, caja, gastos o cola sync
  pendientes.

## Matriz Critica

| Modulo | Riesgo | Archivo/servicio auditado | Hallazgo | Accion | Estado | Prueba asociada |
| --- | --- | --- | --- | --- | --- | --- |
| Checkout POS normal | P0 | `PosBloc`, `SalesRepository`, `LocalSalesDataSource` | La venta se guarda localmente dentro de transaccion y luego se encola. Si inventario/empaque falla, no queda venta parcial. | Mantener. | OK | `pos_bloc_test`, `sales_repository_test` |
| Factura/consecutivo local | P0 | `pos_checkout_helpers.dart` | El POS prepara numero provisional y solo avanza localmente despues de guardar venta. Si falla empaque/inventario, no avanza. Supabase puede renumerar por RPC de dispositivo y actualizar local. | Mantener y validar siempre por prueba de empaque insuficiente. | OK | `does not advance invoice number when checkout save fails`, `SupabaseSyncRemoteSender pushes POS cash and sales through device RPC` |
| Checkout dividido | P0 | `pos_checkout_handlers.dart`, `pos_split_checkout_handlers.dart` | Las cuentas separadas se cobran por venta local y se limpian al completar. Riesgo residual: si varias cuentas se cobran en lote y falla una intermedia, pueden quedar ventas parciales ya cobradas. | Documentar como P2; para V1 usar cobro de cuenta individual si se necesita maxima seguridad operativa. | P2 documentado | `pos_bloc_test` |
| Inventario POS | P0 | `LocalInventoryDataSource`, `SalesRepository` | Productos con stock insuficiente bloquean venta y no insertan venta parcial. Anulacion reintegra stock. | Mantener. | OK | `sales_repository_test` |
| Empaque por tipo de venta | P0 | `LocalPackagingDataSource`, `SalesRepository`, selector POS | Solo descuenta cuando existe regla para el tipo de venta seleccionado. Dine-in no descuenta si no corresponde. Falta de empaque bloquea venta antes de persistirla. | Mantener. | OK | `sales_repository_test`, `pos_bloc_test` |
| Caja POS | P0 | `CashRegisterRepository`, `PosBloc` | POS exige caja abierta, impide operar con caja anterior abierta y no permite cerrar caja si hay pedidos pendientes. | Mantener. | OK | `cash_register_repository_test`, `pos_bloc_test` |
| Gastos POS | P1 | `pos_register_expense_page.dart`, `ExpensesRepository` | Registro desde POS usa local/cola sync por ser operacion POS. No pertenece a admin remoto. | Mantener. | OK | `expenses`/sync tests existentes |
| Tickets abiertos | P0 | `PosOpenTicketRepository` | Tickets de mesa se conservan localmente y se restauran al volver al POS. Se limpian al cobrar. | Mantener. | OK | `pos_bloc_test` |
| Nombres temporales de mesa | P1 | `pos_table_handlers.dart`, pull de catalogo | Nombre visible POS es local-only y no debe subir. Pull de catalogo preserva valores local-only. | Mantener. | OK | `tables_repository_test`, `supabase_catalog_pull_service_test` |
| Disponibilidad diaria modificadores POS | P1 | `ModifiersRepository`, `pos_modifier_availability_page.dart` | Disponibilidad diaria POS es local-only y no sube. Pull remoto preserva estado local. | Mantener. | OK | `modifiers_repository_test`, `supabase_catalog_pull_service_test` |
| Cola de sincronizacion | P0 | `SyncQueueRepository`, `LocalSyncQueueDataSource` | Las operaciones quedan pending/error y son reintentables; items `syncing` viejos vuelven a elegibles despues de 2 minutos. | Mantener. | OK | `sync_queue_repository_test` |
| Sync inmediato POS | P0 | `SyncQueueRepository` | Incidente 2026-07-08: ventas con error podian quedar atras mientras otra venta posterior subia por el disparo inmediato, consumiendo consecutivo remoto fuera del orden de caja. | Serializar `syncOnSave`, respetar primer item pending/error y no bypass de fallos anteriores. | Corregido | `serializes immediate sync in queue order`, `does not bypass an older failed queue item` |
| Procesador sync | P0 | `SyncQueueProcessor` | Procesa FIFO, marca synced/error, y detiene lote si hay fallos para evitar cascada confusa. | Mantener. | OK | `sync_queue_processor_test` |
| Sync POS por dispositivo | P0 | `SupabaseSyncRemoteSender` | Caja y ventas POS usan RPC de dispositivo cuando hay credenciales; no dependen de sesion admin. | Mantener. | OK | `supabase_sync_remote_sender_test` |
| Idempotencia remota | P0 | RPCs y sender Supabase | Inventario/empaque usan movimientos idempotentes; ventas/caja usan ids/local ids y RPC de dispositivo. | Mantener; validar migraciones aplicadas en Supabase antes de release. | OK con verificacion remota requerida | tests sender + checklist manual |
| Admin remoto | P1 | `SupabaseAdminRepository`, DI admin | Pantallas admin principales leen/escriben Supabase directo. `Sincronizacion` y `Utilidades` son excepciones. | Mantener auditoria estatica antes de release. | OK | `ADMIN_REMOTE_AUDIT.md`, `flutter analyze`, `flutter test` |
| Inicializacion APK | P0 | `DeviceInitializationService`, `AuthGate` | Instalacion limpia debe pedir inicializacion si hay Supabase configurado y no hay usuario local. | Mantener y probar en tablet limpia. | OK con prueba manual requerida | `device_initialization_service_test` |
| Actualizacion APK | P0 | `pubspec.yaml`, Android manifest, Drift | `applicationId` estable, permiso internet presente. No cambiar schema sin migracion no destructiva. | Validar con `aapt` y prueba instalar encima. | Pendiente manual por release | checklist manual |
| VersionCode | P1 | `pubspec.yaml`, build release | Version actual auditada: `0.1.15+20`. Cada APK entregable debe aumentar `+versionCode`. | Aplicar regla antes de cada entrega de APK. | Regla documentada | `production_preflight.ps1` |

## Hallazgos P0/P1

No se detecto un P0/P1 nuevo en la lectura estatica de esta fase. Se mantienen
como controles obligatorios:

- no avanzar consecutivo si falla checkout;
- no descontar empaque en comer aqui cuando no corresponde;
- no duplicar ventas por reintentos de sync;
- no actualizar APK desinstalando si hay pendientes;
- no tocar `applicationId`, firma o schema Drift sin plan especifico.

## Riesgos P2 Documentados

- El cobro dividido en lote puede dejar ventas parciales si una cuenta posterior
  falla. En V1, para operacion sensible, se recomienda cobrar cuentas separadas
  una por una.
- El POS conserva un numero provisional local hasta que Supabase confirme o
  renumere la venta sincronizada. Esto es aceptable si la sincronizacion por
  dispositivo esta configurada y validada. Desde 2026-07-08, si una venta queda
  en error, las ventas posteriores no deben bypass-earla por sync inmediato.
- `Sincronizacion` y `Utilidades` no son remoto-only por diseno; no deben ser
  tratadas como pantallas admin normales.

## Incidente P0 2026-07-08: F-36/F-38

Sintoma observado en preproduccion:

- una venta local `F-38` por C$ 395 quedo en error, mientras en Supabase el
  consecutivo `F-38` aparecia con otro monto;
- `F-36` aparecia duplicada localmente con una venta sincronizada y otra con
  error;
- la pantalla POS de transacciones no mostraba detalle local, error tecnico ni
  accion clara de reintento por factura.

Causa raiz tecnica:

- el procesador formal de cola (`SyncQueueProcessor`) ya procesaba FIFO y se
  detenia ante errores;
- pero `SyncQueueRepository.enqueue` disparaba un sync inmediato por item, en
  segundo plano, sin un carril serial global;
- eso podia permitir que una venta posterior llegara a Supabase antes que una
  venta anterior con error, y Supabase, como autoridad del consecutivo, asignara
  el siguiente numero remoto al primer payload que llegara correctamente.

Correccion aplicada:

- `syncOnSave` ahora corre serializado y solo procesa el primer item elegible de
  la cola;
- si existe una venta anterior en `pending/error`, ninguna venta posterior la
  salta por el sync inmediato;
- `pos_sync_sale` remoto valida que el total del encabezado cuadre con el total
  del detalle antes de aplicar la venta;
- al reintentar una venta, Supabase limpia lineas remotas obsoletas que ya no
  existan en el payload local;
- la pantalla POS de transacciones permite abrir el detalle local de cada venta,
  ver productos, total, estado/error de sync y reintentar.

## Comandos De Auditoria

```powershell
flutter analyze
flutter test

rg -n "AdminDataRefreshService|remoteRefreshService" lib/features lib/core/di test -g "*.dart"
rg -n "serviceLocator<I[A-Za-z]+Repository>" lib/features -g "*.dart"
```

Resultado esperado:

- `flutter analyze` sin issues.
- `flutter test` completo exitoso.
- `serviceLocator<I...Repository>` solo en POS/sync operativo.
- `AdminDataRefreshService` no inyectado en pantallas admin.
