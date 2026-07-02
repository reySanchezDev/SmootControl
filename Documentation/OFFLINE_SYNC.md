# Offline Sync - SmooControl

## Objetivo

La app debe operar sin internet para ventas, gastos y anulaciones locales.

## Persistencia Local

- Drift/SQLite.
- Catalogos operativos.
- Mesas.
- Productos.
- Metodos de pago.
- Ventas.
- Detalles.
- Anulaciones.
- Caja diaria.
- Gastos.
- Cola de sincronizacion.

## Implementado

- `AppDatabase` con Drift.
- Conexion IO persistente con `NativeDatabase.createInBackground`.
- Conexion Web preparada con `WasmDatabase.open`.
- Cola local `local_sync_queue`.
- Datasource y repositorio local de cola de sincronizacion.
- Procesador de cola local con estados `pending`, `syncing`, `synced` y `error`.
- Contrato `ISyncRemoteSender` para conectar Supabase cuando exista el proyecto remoto nuevo.
- Enviador remoto deshabilitado de forma explicita hasta configurar Supabase SmooControl.
- Pantalla local de sincronizacion para revisar operaciones pendientes o con error y ejecutar sincronizacion manual.
- Las ventas completadas se encolan como `sales/create` al guardarse localmente.
- Las anulaciones de ventas se encolan como `sales/update` al completarse localmente.
- Los gastos operativos se encolan como `operating_expenses/create` al guardarse localmente.
- Categorias, productos, metodos de pago, mesas y cuentas separadas se encolan al guardarse localmente.
- Apertura/cierre de caja diaria y configuracion del negocio se encolan al guardarse localmente.
- Roles, permisos, asignaciones de permisos y perfiles de usuario se encolan al guardarse localmente.
- Entradas de auditoria local se encolan al guardarse localmente.
- Repositorios offline locales:
  - categorias
  - productos
  - metodos de pago
  - mesas
  - ventas y detalles
  - caja diaria
  - gastos operativos
- Pruebas de escritura/lectura en SQLite en memoria.
- Pruebas de cola local y procesador de sincronizacion.
- Pruebas de BLoC para cargar cola pendiente y procesar operaciones.
- Pruebas de repositorio para confirmar que ventas, anulaciones y gastos crean items en la cola local.
- Pruebas de repositorio para confirmar que catalogos operativos crean items en la cola local.
- Pruebas de repositorio para confirmar que caja diaria y settings crean items en la cola local.
- Pruebas de repositorio para confirmar que roles y usuarios crean items en la cola local.
- Pruebas de repositorio para confirmar que auditoria local crea items en la cola local.

## Web Validado

- Agregado `web/sqlite3.wasm`.
- Agregado `web/drift_worker.dart`.
- Generado `web/drift_worker.js` con `dart compile js -O2 -o web\drift_worker.js web\drift_worker.dart`.
- `tool/build_web_release.ps1` compila release, copia `sqlite3.wasm` y `drift_worker.js` a `build/web`, y usa `--no-web-resources-cdn`.
- Verificacion HTTP release confirma `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js`.

## Estados

- `pending`
- `syncing`
- `synced`
- `error`

## Reglas

- Guardar primero localmente.
- Sincronizar cuando haya conexion.
- Evitar duplicados mediante ids locales/remotos.
- Reintentar errores.
- Mostrar pendientes al usuario.
- Todo payload nuevo debe incluir o poder resolver `restaurant_id`,
  usuario/actor y codigos remotos requeridos por Supabase.
- La pantalla de sincronizacion muestra modulos, operaciones y estados con etiquetas de negocio; no expone ids locales ni nombres tecnicos de tablas.
- No marcar una operacion como sincronizada si el envio remoto no confirma exito.
- Mientras Supabase remoto no este configurado, el envio remoto debe fallar de forma explicita y auditable.

## Regla De Seguridad: Sincronizacion POS Por Dispositivo

La sincronizacion operativa del POS no debe depender de una sesion humana de
administrador, ni de una clave quemada en el APK. Durante la inicializacion de
la tableta, un administrador remoto valida el dispositivo y Supabase registra
una credencial tecnica unica para esa instalacion.

El dispositivo guarda localmente:

- `syncDeviceId`
- `syncDeviceSecret`

Supabase guarda solo el hash del secreto en `pos_devices`. Las ventas y cajas
se suben por RPCs controlados:

- `pos_sync_cash_register_session`
- `pos_sync_sale`
- `pos_sync_operating_expense`
- `pos_sync_table_account`

Esos RPCs validan el dispositivo activo antes de escribir y no habilitan acceso
general al catalogo administrativo. La sesion remota del propietario se usa
para inicializar/restaurar y administrar; el POS usa PIN local y credencial de
dispositivo para sincronizar.

Si una tableta fue inicializada antes de existir esta credencial, debe
restaurarse nuevamente desde Supabase para activar la sincronizacion POS por
dispositivo.

### Incidente Documentado: `pgcrypto.digest` En RPC De Dispositivo

El 2026-07-01 la inicializacion Web/APK validaba correctamente el administrador
remoto, pero fallaba al restaurar el dispositivo con el mensaje generico
`No se pudo restaurar la tableta desde Supabase`.

Causa real:

- `register_pos_device` y `assert_pos_device` usaban `digest()` de `pgcrypto`.
- En Supabase la extension vive en el esquema `extensions`.
- Las funciones `SECURITY DEFINER` estaban con `search_path = public`.
- PostgREST devolvia error de RPC porque dentro de la funcion no encontraba
  `digest(text, unknown)`.

Correccion:

- Migracion `012_pos_device_pgcrypto_search_path.sql`.
- `CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions`.
- Funciones con `SET search_path = public, extensions`.
- Uso explicito de `extensions.digest(...)`.

Regla para futuros RPCs:

- Toda funcion `SECURITY DEFINER` que use extensiones debe declarar el esquema
  requerido en `search_path` o llamar la funcion con esquema explicito.
- Despues de migrar RPCs se debe probar por HTTP real, no solo verificando que
  la funcion exista en Postgres.

## Regla Operativa: POS No Depende De La Red

La venta, el gasto, la apertura/cierre de caja y los cambios operativos deben
confirmarse contra la base local antes de cualquier intento remoto. La
sincronizacion no puede detener la operacion de vender.

Flujo esperado para una venta:

1. Guardar venta y detalle en Drift/SQLite.
2. Encolar la operacion en `local_sync_queue`.
3. Limpiar el ticket abierto de la mesa.
4. Intentar sincronizar en segundo plano si la configuracion lo permite.
5. Si Supabase o la red fallan, conservar la venta local y dejar la cola como
   reintentable.

## Decision: Sin Pre-Check De Conexion En V1

En V1 no se hace un `ping` ni una prueba previa de conexion antes de intentar
sincronizar. La prueba efectiva de conectividad es el propio intento de envio
remoto.

Razon:

- Reduce carga y complejidad en el POS.
- Evita depender de un indicador de conexion que puede ser falso positivo:
  puede haber internet y Supabase estar lento, bloqueado o caido.
- Mantiene una sola fuente de verdad para el resultado: la respuesta real del
  envio remoto.

Defensas obligatorias:

- El intento remoto tiene timeout.
- Si falla, el item queda en `error` y se vuelve a intentar despues.
- Si la app se cierra mientras un item esta `syncing`, el item se considera
  reintentable cuando queda viejo.
- La sincronizacion inmediata se dispara en segundo plano y no bloquea el
  retorno de la operacion local.

Esta decision puede revisarse si en produccion se observa que los intentos
fallidos consumen demasiados recursos o ensucian la operacion. En ese caso se
podria agregar un servicio de conectividad previo sin eliminar los timeouts ni
la cola reintentable.

## Reintentos Y Recuperacion

La cola procesa como reintentables los items en:

- `pending`
- `error`
- `syncing` viejo, usado para recuperar items atascados por cierre de app,
  apagado del dispositivo o corte durante el envio.

Un fallo temporal de red, timeout de Supabase o app cerrada a media
sincronizacion no debe perder la venta ni bloquear ventas nuevas. El item queda
en cola y se procesa por sincronizacion automatica o manual.

Si el error es permanente por datos invalidos o una restriccion remota, el item
seguira reintentando pero continuara fallando hasta corregir la causa. Ese caso
debe revisarse desde la pantalla de sincronizacion usando el ultimo error.
