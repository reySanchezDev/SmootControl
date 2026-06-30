# Arquitectura: Sistema Administrativo Online + POS Offline

## Objetivo

SmooControl debe operar con dos comportamientos separados:

- El sistema administrativo trabaja online contra Supabase como fuente central.
- El POS mantiene una copia local para vender sin internet y sincronizar despues.

Esta decision evita convertir todo el sistema en offline-first. Solo el flujo que
no puede detenerse por falta de internet, el POS, conserva operacion local.

## Reglas De Arquitectura

### Administracion Online-First

Los modulos administrativos deben leer y escribir contra Supabase:

- categorias
- productos
- modificadores
- mesas
- metodos de pago
- usuarios
- roles
- permisos
- tasas de cambio
- configuracion
- reportes administrativos

Si no hay internet, administracion debe bloquear edicion y mostrar:

> Se requiere conexion para administrar.

La base local no debe ser la fuente principal de administracion. Mientras se
migra por fases, los repositorios locales existentes pueden seguir funcionando,
pero el destino final es remoto.

### POS Offline-First

El POS debe seguir operando sobre Drift/SQLite local para:

- tickets abiertos
- ventas
- caja
- gastos desde POS
- mesas operativas
- catalogo descargado
- metodos de pago
- tasas de cambio
- usuarios POS necesarios para login local

El POS guarda primero localmente y luego sube por la cola de sincronizacion.
La sincronizacion no puede bloquear ventas nuevas.

## Flujo De Datos

Administracion:

```text
UI administrativa -> Supabase -> verdad central
```

POS:

```text
Supabase -> descarga catalogo/configuracion -> Drift local del POS
Drift local del POS -> ventas/caja/gastos -> cola sync -> Supabase
```

## Recuperacion Desde Supabase

Una tableta nueva o reseteada debe poder restaurarse desde Supabase:

1. autenticar/restaurar contexto remoto;
2. descargar restaurante y configuracion;
3. descargar usuarios POS, roles y permisos;
4. descargar catalogos, productos, modificadores, mesas, tasas y metodos;
5. quedar lista para vender.

La unica perdida aceptable son movimientos hechos offline que nunca lograron
subir antes de perder o borrar el dispositivo.

## Migracion Progresiva

1. Documentar la arquitectura y proteger pantallas administrativas con conexion.
2. Completar pull remoto de usuarios, roles, permisos y configuracion.
3. Migrar repositorios administrativos a Supabase directo.
4. Migrar reportes administrativos para consultar Supabase.
5. Optimizar bajada incremental y automatica.

## Estado De Implementacion

### Fase 1

Implementada:

- Pantallas administrativas protegidas por conexion.
- POS mantiene operacion offline local.
- Boton **Sincronizar datos** baja catalogo operativo desde Supabase.

### Fase 2

Implementada en la descarga manual del POS:

- configuracion del restaurante desde `restaurants`;
- numeracion desde `invoice_number_settings`;
- roles desde `roles`;
- permisos desde `permissions`;
- asignaciones desde `role_permissions`;
- usuarios desde `profiles`;
- catalogos operativos, mesas, tasas, metodos de pago y categorias de gasto.

Para restaurar usuarios POS completamente desde una tableta nueva, el remoto debe
tener aplicada la migracion `003_pos_user_restore_fields.sql`, que agrega
`pin_salt`, `pin_hash` e `is_pos_user` a `profiles`. Sin esos campos, se pueden
bajar los perfiles, pero el login local por PIN no queda restaurado para usuarios
nuevos.

En esta fase no se inactivan ni eliminan usuarios, roles o permisos locales si no
vienen en la respuesta remota. La regla temporal es conservadora para no bloquear
una tableta operativa por una configuracion remota incompleta.

### Fase 3

Primer corte implementado:

- `profiles`, `roles` y `role_permissions` ya no se ignoran en el envio remoto.
- Al guardar usuarios se envia `pin_salt`, `pin_hash` e `is_pos_user` para que
  puedan restaurarse desde otra tableta.
- Supabase acepta perfiles operativos que no dependen de una cuenta
  `auth.users`.
- Supabase acepta roles con identificadores locales estables, por ejemplo
  `role-admin`, `role-cashier` y `role-waiter`.
- La bajada de roles usa los roles propios del restaurante cuando existen; los
  roles globales solo funcionan como plantilla inicial si todavia no hay roles
  del restaurante.

Pendiente de esta fase:

- migrar repositorios administrativos de catalogo/productos/mesas/pagos para
  leer y escribir directo contra Supabase;
- convertir reportes administrativos a consultas remotas;
- definir un flujo formal para crear usuarios desde administracion con
  confirmacion de subida remota visible.

### Fase 4

Catalogos online-first implementados:

- categorias y productos suben primero a Supabase cuando la app tiene sender
  remoto configurado;
- modificadores, mesas, metodos de pago, tasas de cambio y categorias de gasto
  tambien suben primero a Supabase en sus operaciones administrativas de
  guardado;
- solo despues de una respuesta remota correcta se actualiza la cache local que
  usa el POS;
- si Supabase rechaza la operacion, no se guarda una version local que pueda
  confundir al administrador;
- las pruebas locales sin sender remoto conservan el comportamiento offline con
  cola, para no romper escenarios aislados ni el POS offline.
- movimientos operativos del POS, como ventas, gastos registrados desde POS,
  cuentas de mesa y caja, siguen offline-first.

Resuelto posteriormente:

- las eliminaciones jerarquicas remotas quedaron cubiertas en Fase 9 para
  categorias, metodos de pago y categorias de gasto.

### Fase 5

Lecturas administrativas con refresco remoto implementadas:

- las pantallas administrativas con BLoC intentan descargar su seccion remota
  antes de leer la cache local;
- tasas de cambio, que usa `FutureBuilder` directo, tambien refresca solo las
  tasas remotas antes de leer tasas locales;
- si la descarga remota falla, la pantalla administrativa muestra error en vez
  de presentar cache vieja como dato actual;
- el POS no usa este refresco obligatorio, por lo que conserva su operacion
  offline-first.
- el boton **Sincronizar datos** del POS conserva la descarga completa para
  restaurar catalogos/configuracion de una tableta nueva o reseteada.
- la descarga administrativa esta separada por scope:
  `businessSettings`, `accessControl`, `catalog`, `products`, `modifiers`,
  `paymentMethods`, `tables`, `expenseCategories` y `exchangeRates`.
- productos descarga tambien categorias y modificadores, porque son dependencias
  visuales y funcionales del formulario de productos.

Pendiente de esta fase:

- optimizar cada scope para que sea incremental por `updated_at` cuando todas
  las tablas remotas tengan una columna confiable de versionado;
- las eliminaciones jerarquicas remotas ya no quedan pendientes de produccion:
  se resolvieron en Fase 9. La optimizacion incremental queda como mejora
  posterior.

### Fase 6

Reportes administrativos online-first implementados:

- la pantalla de reportes usa Supabase como fuente cuando la configuracion
  remota esta disponible;
- el POS no cambia su comportamiento: ventas, caja y gastos siguen guardandose
  localmente primero y luego suben por la cola;
- el reporte remoto consulta ventas, detalles de venta, anulaciones, cajas,
  gastos, categorias de gasto y metodos de pago directamente desde Supabase;
- los montos remotos se convierten desde moneda decimal a centavos para
  conservar el mismo calculo interno que usa Flutter;
- las pruebas sin Supabase configurado conservan el calculo local como respaldo
  de desarrollo.

Pendiente de esta fase:

- agregar filtros avanzados de reportes directamente contra Supabase;
- optimizar consultas remotas para rangos grandes con vistas o RPC SQL si el
  volumen de ventas crece.

Nota operativa:

- no se muestra advertencia de cola local pendiente dentro de reportes remotos,
  porque el administrador puede entrar desde otro equipo y ese equipo no tiene
  acceso a la cola local de la tableta POS;
- la regla sigue siendo que los reportes administrativos muestran la verdad
  central de Supabase: una venta offline solo aparecera cuando el POS logre
  sincronizarla.

### Fase 7

Recuperacion de tableta desde Supabase validada:

- se agrego una prueba automatizada que simula una base local vacia y respuestas
  remotas de Supabase;
- la descarga completa del POS restaura configuracion del negocio, numeracion,
  permisos, roles, usuarios POS, categorias, modificadores, productos, metodos
  de pago, mesas, categorias de gasto y tasas de cambio;
- la prueba no depende de internet ni del proyecto real de Supabase: usa un
  cliente HTTP falso, pero recorre el mismo servicio que usa el boton
  **Sincronizar datos**;
- esta prueba protege el escenario de una tableta nueva, reseteada o reinstalada
  antes de salir a produccion.

Pendiente de esta fase:

- ejecutar la misma validacion manual contra el Supabase real antes de generar
  el APK final;
- confirmar en una instalacion limpia de Android que, despues de sincronizar
  datos, el usuario POS puede iniciar sesion y vender.

### Fase 8

Diagnostico de POS listo para vender implementado:

- el resultado de **Sincronizar datos** ahora evalua si la descarga completa
  contiene los minimos para operar el POS;
- los minimos validados son configuracion del negocio, usuarios POS, roles,
  permisos, asignaciones rol-permiso, categorias, productos, metodos de pago,
  mesas y tasas de cambio;
- si falta una pieza critica, el dialogo de sincronizacion muestra una
  advertencia concreta con la lista de datos faltantes;
- esta validacion ayuda a detectar una restauracion incompleta antes de empezar
  a operar en produccion.

### Fase 9

Eliminaciones administrativas remotas seguras implementadas:

- las eliminaciones de categorias de producto, metodos de pago y categorias de
  gasto ahora son remote-first cuando Supabase esta configurado;
- si Supabase rechaza la eliminacion por relaciones historicas o cualquier error
  remoto, la cache local no se modifica;
- al eliminar una subcategoria de producto, Supabase mueve primero sus
  subcategorias hijas y productos al padre antes de borrar el nivel;
- al eliminar un nivel de metodo de pago, Supabase mueve primero sus hijos al
  padre antes de borrar el nivel;
- al eliminar una categoria de gasto, Supabase mueve primero sus hijos a raiz
  antes de borrar la categoria;
- si una categoria/metodo esta usado por datos historicos y la base remota lo
  bloquea, la operacion falla de forma segura y no deja divergencia local/remota.

### Fase 10

Cierre de salida a produccion documentado:

- se agrego `Documentation/PRODUCTION_GO_LIVE_CHECKLIST.md` como checklist
  operativo para instalar, restaurar, probar venta offline, sincronizar y validar
  reportes remotos;
- la regla de actualizacion queda documentada: mantener `applicationId`, firma
  release y migraciones no destructivas para poder actualizar APK sin perder
  datos locales;
- la regla de rescate queda documentada: catalogo, configuracion, usuarios POS,
  roles, permisos, mesas, tasas y metodos se pueden restaurar desde Supabase;
- las ventas o gastos hechos offline solo se pueden recuperar si lograron
  sincronizar antes de perder o borrar la tableta.

## Criterios De Aceptacion

- El POS vende sin internet.
- Administracion no permite operar sin internet.
- Un cambio administrativo remoto baja al POS con **Sincronizar datos**.
- Ventas offline se conservan localmente y suben cuando vuelve la conexion.
- Una tableta nueva puede restaurar datos centrales desde Supabase.
- Una actualizacion APK mantiene `applicationId`, firma release y migraciones no
  destructivas.
