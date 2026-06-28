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
