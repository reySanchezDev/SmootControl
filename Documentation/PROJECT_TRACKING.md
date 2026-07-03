# Seguimiento Del Proyecto - SmooControl

## Estados Permitidos

- Pendiente
- En progreso
- Bloqueado
- En revision
- Completado

## Resumen Actual

| Area | Estado | Ultima actualizacion | Notas |
| --- | --- | --- | --- |
| Workspace Flutter | Completado | 2026-06-22 | Proyecto Android/Web creado y validado. |
| Design System | En progreso | 2026-06-23 | Base minima creada. |
| l10n es/en | En progreso | 2026-06-23 | ARB inicial creado y generado. |
| Arquitectura feature-first | En progreso | 2026-06-24 | Core, navegacion, DI, resultados, entidades, repositorios data, BLoCs iniciales y acceso local creados. |
| Offline local Drift | En progreso | 2026-06-24 | Tablas locales, conexion por plataforma, repositorios locales y cola/procesador sync base creados. |
| Pantallas base | En progreso | 2026-06-23 | Dashboard, formularios, POS, reportes y settings iniciales creados. |
| Supabase local | En progreso | 2026-06-22 | Configuracion, seed y migracion inicial creados. |
| Supabase remoto | En progreso | 2026-06-28 | Proyecto SmooControl enlazado, migraciones 001/002 y seed aplicados; sender remoto conectado por dart-define. |

## Checklist De Fase

### Fase 1 - Preparar Workspace

- [x] Crear proyecto Flutter.
- [x] Habilitar Android y Web.
- [x] Configurar dependencias base.
- [x] Configurar l10n es/en.
- [x] Crear Design System minimo.
- [x] Ejecutar analisis limpio.
- [x] Ejecutar tests iniciales.

### Fase 2 - Documentacion De Control

- [x] Crear PROJECT_TRACKING.
- [x] Crear BUSINESS_RULES.
- [x] Crear ARCHITECTURE.
- [x] Crear DATABASE.
- [x] Crear CATALOGS.
- [x] Crear SCREENS_AND_FLOWS.
- [x] Crear RESPONSIVE_GUIDE.
- [x] Crear SUPABASE_PLAN.
- [x] Crear OFFLINE_SYNC.
- [x] Crear SUPABASE_READINESS_AUDIT.

### Fase 3 - Arquitectura Feature-First

- [x] Crear `core/di`.
- [x] Crear `core/navigation`.
- [x] Crear `core/result`.
- [x] Crear entidades iniciales de catalogo, productos, metodos de pago, mesas, ventas, caja y gastos.
- [x] Crear contratos iniciales de repositorios.
- [x] Crear servicio de dominio para separacion de cuentas.
- [x] Agregar pruebas del servicio de separacion de cuentas.
- [x] Crear modelos `data` y datasources locales/remotos.
  - [x] Catalogo: modelo, datasource local y repositorio local.
  - [x] Productos: modelo, datasource local y repositorio local.
  - [x] Metodos de pago: modelo, datasource local y repositorio local.
  - [x] Mesas: modelo, datasource local y repositorio local.
  - [x] Ventas: modelos, datasource local, detalle y repositorio local.
  - [x] Caja diaria: modelo, datasource local y repositorio local.
  - [x] Gastos: modelos, datasource local y repositorio local.
  - [x] Settings: modelo, datasource local y repositorio local.
  - [x] Roles/permisos: modelos, datasource local y repositorio local.
  - [x] Usuarios: modelo, datasource local y repositorio local.
- [x] Crear BLoCs iniciales con estados de error.
  - [x] Catalogo.
  - [x] Productos.
  - [x] Metodos de pago.
  - [x] Mesas.
  - [x] Ventas.
  - [x] Caja diaria.
  - [x] Gastos.
  - [x] Settings.
  - [x] Roles.
  - [x] Usuarios.

### Fase 5 - Offline-First

- [x] Crear base Drift/SQLite.
- [x] Crear tablas locales principales.
- [x] Crear cola local de sincronizacion.
- [x] Registrar `AppDatabase` en DI.
- [x] Crear pruebas basicas de persistencia local.
- [x] Agregar assets Web de Drift (`sqlite3.wasm`, `drift_worker.js`).
- [x] Crear servicio base de sincronizacion local.
- [x] Crear pantalla local de seguimiento y sincronizacion manual.
- [x] Conectar servicio de sincronizacion con Supabase remoto nuevo.

### Fase 6 - Funcionalidad V1

- [x] Crear navegacion base de modulos.
- [x] Crear pantallas base conectadas a BLoC para catalogo, productos, metodos de pago, mesas, ventas y gastos.
- [x] Crear pantallas base para POS, caja diaria y reportes.
- [x] Crear formularios reales de alta basica.
  - [x] Categorias.
  - [x] Productos.
  - [x] Metodos de pago.
  - [x] Mesas.
  - [x] Categorias de gastos.
  - [x] Gastos operativos.
  - [x] Apertura/cierre de caja.
- [x] Crear formularios de edicion.
- [x] Crear POS responsivo basico con grilla de productos, carrito, metodo de pago y cobro local.
- [x] Agregar navegacion POS por categorias y subcategorias.
- [x] Agregar seleccion de mesa en POS y persistir `tableId` en ventas.
- [x] Asociar ventas POS y gastos operativos a la caja diaria abierta de forma interna.
- [x] Agregar UI inicial de cuentas separadas desde carrito con validacion de asignacion completa.
- [x] Convertir cuentas separadas en ventas independientes con `tableAccountId`.
- [x] Mejorar cuentas separadas con pagos individuales por cuenta.
- [x] Crear reportes iniciales de ventas, ganancias, gastos, ganancia real y productos mas vendidos.
- [x] Agregar selector de fecha y detalle auditable de anulaciones en reportes.
- [x] Crear settings inicial para datos de empresa, visibilidad en PDF y numeracion de facturas.
- [x] Crear PDF basico de comprobante no fiscal desde ventas.
- [x] Agregar selector de fecha en transacciones para auditoria y reimpresion por dias anteriores.
- [x] Agregar disponibilidad diaria y grupos de opciones obligatorias por producto para POS.

## Comandos Ejecutados

| Fecha | Comando | Resultado |
| --- | --- | --- |
| 2026-06-22 | `flutter create --platforms=android,web --empty --project-name smoo_control .` | Proyecto creado. |
| 2026-06-22 | `flutter pub add ...` | Dependencias agregadas. |
| 2026-06-22 | `flutter gen-l10n` | Localizaciones generadas. |
| 2026-06-22 | `flutter analyze` | Sin issues. |
| 2026-06-22 | `flutter test` | Tests iniciales pasan. |
| 2026-06-23 | `mcp__dart.add_roots` | Raiz SmooControl registrada. |
| 2026-06-23 | `mcp__dart.dart_format` | Formato aplicado; se restauro VIGGO donde fue tocado accidentalmente. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | Sin cambios pendientes. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 4 tests pasan. |
| 2026-06-23 | Verificacion de `Recursos/VIGGO` | Carpeta removida del workspace. |
| 2026-06-23 | `dart run build_runner build --delete-conflicting-outputs` | Codigo Drift generado; flag obsoleto ignorado por build_runner. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de Drift. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 7 tests pasan. |
| 2026-06-23 | `flutter build web --debug` | Build Web correcto; advertencia no bloqueante de wasm dry run en dependencia `ua_client_hints`. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | 9 archivos formateados. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de repositorios locales. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 12 tests pasan. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | 4 archivos de ventas formateados. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de ventas locales. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 14 tests pasan. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | 2 archivos de BLoC formateados. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de BLoCs iniciales. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 22 tests pasan. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | 1 archivo de pruebas BLoC formateado. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de BLoCs operativos. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 31 tests pasan. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para nuevas pantallas. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | 6 pantallas formateadas. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de pantallas base. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 31 tests pasan despues de pantallas base. |
| 2026-06-23 | `flutter build web --debug` | Build Web correcto; advertencia no bloqueante de wasm dry run en dependencia `ua_client_hints`. |
| 2026-06-23 | `flutter run -d chrome --web-port 8085` | Servidor local activo en `http://localhost:8085`. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para formularios de alta. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | 7 archivos de paginas/dialogos formateados. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de formularios de alta. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 31 tests pasan despues de formularios de alta. |
| 2026-06-23 | `flutter build web --debug` | Build Web correcto; advertencia no bloqueante de wasm dry run en dependencia `ua_client_hints`. |
| 2026-06-23 | `flutter run -d chrome --web-port 8085` | Servidor local reiniciado en `http://localhost:8085`. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para POS basico. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | POS y pruebas formateados. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de POS basico. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 35 tests pasan. |
| 2026-06-23 | `flutter build web --release` | Build Web release correcto; advertencia no bloqueante de wasm dry run en `ua_client_hints`. |
| 2026-06-23 | `python -m http.server 8085 --directory build/web` | Sitio release servido en `http://localhost:8085`; verificacion HTTP 200. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para navegacion POS. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | POS por categorias formateado. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de navegacion por categorias. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 36 tests pasan. |
| 2026-06-23 | `flutter build web --release` | Build Web release correcto; advertencia no bloqueante de wasm dry run en `ua_client_hints`. |
| 2026-06-23 | `python -m http.server 8085 --directory build/web` | Sitio release actualizado en `http://localhost:8085`; verificacion HTTP 200. |
| 2026-06-23 | `dart compile js -O2 -o web\drift_worker.js web\drift_worker.dart` | Worker Web de Drift compilado. |
| 2026-06-23 | Copia de `sqlite3.wasm` y `drift_worker.js` a `build/web` | Assets runtime de Drift disponibles por HTTP 200. |
| 2026-06-23 | `tool\build_web_release.ps1` | Script agregado para compilar release Web y copiar assets Drift automaticamente. |
| 2026-06-23 | Prueba Edge/CDP en `http://localhost:8085` | Dashboard renderizado; sin excepciones runtime. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | Checkout de cuentas separadas formateado. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de facturar cuentas separadas. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 40 tests pasan. |
| 2026-06-23 | `flutter build web --release` | Build Web release correcto; advertencia no bloqueante de wasm dry run en `ua_client_hints`. |
| 2026-06-23 | `python -m http.server 8085 --directory build/web` | Sitio release actualizado en `http://localhost:8085`; verificacion HTTP 200. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para cuentas separadas. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | BLoC POS y dialogo de separacion formateados. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de cuentas separadas iniciales. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 38 tests pasan. |
| 2026-06-23 | `flutter build web --release` | Build Web release correcto; advertencia no bloqueante de wasm dry run en `ua_client_hints`. |
| 2026-06-23 | `python -m http.server 8085 --directory build/web` | Sitio release actualizado en `http://localhost:8085`; verificacion HTTP 200. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para selector de mesa POS. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | Selector de mesa POS formateado. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de selector de mesa POS. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 36 tests pasan. |
| 2026-06-23 | `flutter build web --release` | Build Web release correcto; advertencia no bloqueante de wasm dry run en `ua_client_hints`. |
| 2026-06-23 | `python -m http.server 8085 --directory build/web` | Sitio release actualizado en `http://localhost:8085`; verificacion HTTP 200. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para caja y gastos. |
| 2026-06-23 | `mcp__dart.dart_format` con `paths: lib,test` | 5 archivos de caja/gastos formateados. |
| 2026-06-23 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de caja/gastos. |
| 2026-06-23 | `mcp__dart.run_tests` con `paths: test` | 32 tests pasan. |
| 2026-06-23 | `flutter build web --debug` | Build Web correcto; advertencia no bloqueante de wasm dry run en dependencia `ua_client_hints`. |
| 2026-06-23 | `flutter run -d chrome --web-port 8085` | Servidor local reiniciado en `http://localhost:8085`. |
| 2026-06-23 | Auditoria funcional de formularios operativos | Detectada exposicion de IDs, orden tecnico y montos en centavos; documentado en `FUNCTIONAL_AUDIT.md`. |
| 2026-06-23 | Correccion de alta de catalogo | Categoria no solicita padre; subcategoria selecciona categoria por nombre; ID y orden son automaticos. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para tipo de categoria/subcategoria. |
| 2026-06-23 | `dart format` | Catalogo y test de dialogo formateados. |
| 2026-06-23 | `mcp__dart.add_roots` | Fallo por transporte cerrado; se continuo con CLI local. |
| 2026-06-23 | `flutter analyze` | 18 issues existentes de calidad/lint; sin bloqueo funcional del cambio de catalogo. |
| 2026-06-23 | `flutter test test\features\catalog\presentation\widgets\create_category_dialog_test.dart` | 2 tests pasan; valida que no se expongan IDs/orden y que subcategoria seleccione padre por nombre. |
| 2026-06-23 | `flutter test` | 42 tests pasan. |
| 2026-06-23 | `tool\build_web_release.ps1` | Build Web release correcto y assets Drift copiados. |
| 2026-06-23 | Prueba Edge/CDP en `http://localhost:8092/#/catalog` | Catalogo renderiza en release y modal no muestra IDs ni orden. |
| 2026-06-23 | Auditoria general de pantallas `presentation` | Revisados formularios/listas de Catalogo, Productos, Gastos, Caja, POS, Ventas, Mesas y Metodos de pago. |
| 2026-06-23 | Correccion de Productos | Producto selecciona categoria/subcategoria por lista; precio/costo se capturan como moneda visible. |
| 2026-06-23 | Correccion de Gastos | Gasto selecciona categoria por lista; no pide ID de caja ni registrado por; monto se captura como moneda visible. |
| 2026-06-23 | Correccion de Caja diaria | Apertura no pide cajero; cierre no pide ID de caja; montos se capturan/muestran como moneda visible. |
| 2026-06-23 | Correccion de POS/Ventas | Montos de productos, carrito y ventas se muestran como moneda visible. |
| 2026-06-23 | `flutter gen-l10n` | Eliminadas etiquetas tecnicas no usadas: IDs, orden y centavos. |
| 2026-06-23 | `flutter test` | 42 tests pasan despues de auditoria general de UI. |
| 2026-06-23 | `flutter analyze` | 18 issues previos; no quedaron issues nuevos por la auditoria general. |
| 2026-06-23 | Reportes V1 iniciales | Agregado servicio/BLoC/pantalla de reportes por dia, semana, mes y año; incluye productos mas y menos vendidos. |
| 2026-06-23 | `flutter test` | 43 tests pasan despues de reportes iniciales. |
| 2026-06-23 | `flutter analyze` | 17 issues previos; sin issues nuevos por reportes. |
| 2026-06-23 | `tool\build_web_release.ps1` | Build Web release correcto despues de reportes; advertencia conocida por carpeta `build` en uso. |
| 2026-06-23 | Prueba Edge/CDP en `http://localhost:8092/#/reports` | Reportes renderizan en release con tarjetas y selector de periodo. |
| 2026-06-23 | Settings V1 inicial | Agregados datos de negocio, visibilidad en PDF y numeracion local de facturas. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para settings. |
| 2026-06-23 | `dart run build_runner build --delete-conflicting-outputs` | Codigo Drift regenerado para `local_business_settings`; flag obsoleto reportado por build_runner. |
| 2026-06-23 | `dart format lib test` | Settings formateado; pantalla queda en 299 lineas. |
| 2026-06-23 | `flutter test` | 45 tests pasan despues de settings. |
| 2026-06-23 | `flutter analyze` | 17 issues previos; sin issues nuevos por settings. |
| 2026-06-23 | PDF basico de ventas | Agregado servicio PDF con fuente Roboto embebida y boton en transacciones del dia. |
| 2026-06-23 | `flutter pub get` | Assets de fuente registrados para PDF con soporte de acentos. |
| 2026-06-23 | `flutter test` | 46 tests pasan despues de PDF basico. |
| 2026-06-23 | `flutter analyze` | 17 issues previos; sin issues nuevos por PDF. |
| 2026-06-23 | `tool\build_web_release.ps1` | Build Web release correcto despues de settings/PDF. |
| 2026-06-23 | Prueba Edge/CDP en `http://localhost:8092/#/settings` | Settings renderiza en desktop y movil sin pantalla blanca. |
| 2026-06-23 | Prueba Edge/CDP en `http://localhost:8092/#/sales` | Ventas renderiza en release. |
| 2026-06-23 | Ajuste Settings numeracion | Removido campo visible de contador siguiente; el sistema lo conserva e incrementa internamente. |
| 2026-06-23 | Mantenimiento de catalogos | Agregada edicion e inactivacion logica en categorias, productos, metodos de pago, mesas y categorias de gastos. |
| 2026-06-23 | Pruebas de mantenimiento | Agregados widget tests de edicion para categorias, productos, metodos de pago, mesas y categorias de gastos. |
| 2026-06-23 | Anulaciones desde ventas | Agregado dialogo con motivo obligatorio, accion en transacciones del dia y recarga de ventas. |
| 2026-06-23 | `flutter test` | 52 tests pasan despues de anulaciones desde ventas. |
| 2026-06-23 | `flutter analyze` | 17 issues previos; sin issues nuevos por anulaciones. |
| 2026-06-23 | Reporte de anulaciones | Agregado conteo de anulaciones por periodo usando fecha real de anulacion. |
| 2026-06-23 | `flutter test` | 52 tests pasan despues de conteo de anulaciones en reportes. |
| 2026-06-23 | Caja diaria integrada a POS/gastos | Ventas y gastos guardan `cash_register_session_id` si existe caja abierta del dia. |
| 2026-06-23 | `dart run build_runner build --delete-conflicting-outputs` | Codigo Drift regenerado para `local_sales.cash_register_session_id`; flag obsoleto reportado por build_runner. |
| 2026-06-23 | `flutter test` | 52 tests pasan despues de integrar caja diaria con ventas/gastos. |
| 2026-06-23 | `flutter analyze` | 13 issues previos; sin issues nuevos por integracion de caja. |
| 2026-06-23 | Resumen de caja diaria | Caja muestra efectivo inicial, ventas en efectivo, gastos, efectivo esperado, conteo fisico y diferencia. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para resumen de caja. |
| 2026-06-23 | `flutter test test\features\cash_register test\features\pos\presentation\bloc\pos_bloc_test.dart` | 10 tests pasan despues del resumen de caja. |
| 2026-06-23 | `flutter analyze` | 13 issues previos; sin issues nuevos por resumen de caja. |
| 2026-06-23 | Vista general de gastos | Pantalla de gastos muestra categorias y gastos registrados hoy sin exponer IDs internos. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para secciones de gastos. |
| 2026-06-23 | `flutter test test\features\expenses` | 6 tests pasan despues de vista general de gastos. |
| 2026-06-23 | `flutter analyze` | 13 issues previos; sin issues nuevos por vista general de gastos. |
| 2026-06-23 | Correccion general de problemas visibles | Estados de caja/mesas localizados, separador corrupto de categorias corregido, categoria historica de venta guarda nombre visible y deuda de analisis limpiada. |
| 2026-06-23 | `flutter gen-l10n` | Localizaciones regeneradas para estados de caja y mesas. |
| 2026-06-23 | `flutter analyze` | Sin issues. |
| 2026-06-23 | `flutter test` | 52 tests pasan despues de correccion general. |
| 2026-06-23 | `tool\build_web_release.ps1` | Build Web release correcto despues de correccion general. |
| 2026-06-23 | Reportes auditables | Agregado selector de fecha, rango visible y detalle de anulaciones por periodo. |
| 2026-06-23 | Idioma V1 | App forzada a idioma español para cumplir alcance confirmado. |
| 2026-06-23 | `flutter analyze` | Sin issues despues de reportes auditables e idioma español. |
| 2026-06-23 | `flutter test` | 52 tests pasan despues de reportes auditables e idioma español. |
| 2026-06-23 | `tool\build_web_release.ps1` | Build Web release correcto despues de reportes auditables e idioma español. |

| 2026-06-23 | Transacciones por fecha | Ventas permite seleccionar fecha y recarga la misma fecha despues de anular una venta. |
| 2026-06-23 | Auditoria estatica de textos tecnicos visibles | Sin etiquetas visibles de ID, orden ni centavos en formularios operativos. |
| 2026-06-23 | `flutter analyze` | Sin issues despues de transacciones por fecha. |
| 2026-06-23 | `flutter test` | 52 tests pasan despues de transacciones por fecha. |
| 2026-06-23 | Catalogo multinivel | Campo Tipo eliminado; categorias se ubican en raiz o dentro de cualquier categoria activa permitida. |
| 2026-06-23 | `flutter analyze` | Sin issues despues de catalogo multinivel. |
| 2026-06-23 | `flutter test test\features\catalog\presentation\widgets\create_category_dialog_test.dart` | 3 tests pasan; valida categoria anidada debajo de subcategoria. |
| 2026-06-23 | `flutter test` | 52 tests pasan despues de catalogo multinivel. |
| 2026-06-24 | Ruta completa en productos | Selector de categoria de producto muestra jerarquia completa y evita overflow. |
| 2026-06-24 | Prueba de fecha de anulacion | Ajustada prueba para consultar anulaciones por fecha real de anulacion. |
| 2026-06-24 | `flutter test test\features\products\presentation\widgets\create_product_dialog_test.dart` | 2 tests pasan; valida ruta completa en categoria anidada. |
| 2026-06-24 | `flutter test test\features\sales\data\repositories\sales_repository_test.dart` | 2 tests pasan; valida anulaciones por dia actual de ejecucion. |
| 2026-06-24 | `flutter test` | 53 tests pasan despues de ruta completa en productos. |
| 2026-06-24 | `flutter analyze` | Sin issues despues de ruta completa en productos. |
| 2026-06-24 | Ruta visible en lista de productos | La lista de productos muestra categoria completa junto al estado. |
| 2026-06-24 | `flutter analyze` | Sin issues despues de mostrar ruta en lista de productos. |
| 2026-06-24 | `flutter test` | 53 tests pasan despues de mostrar ruta en lista de productos. |
| 2026-06-24 | Caja en reportes | Reportes agrega cajas registradas, efectivo inicial, ventas en efectivo, gastos desde caja, esperado, fisico y diferencia. |
| 2026-06-24 | `flutter analyze` | Sin issues despues de caja en reportes. |
| 2026-06-24 | `flutter test` | 53 tests pasan despues de caja en reportes. |
| 2026-06-24 | Disponibilidad diaria de productos | Agregado campo para ocultar productos del POS sin inactivarlos historicamente. |
| 2026-06-24 | Acompañamientos de platos | Regla documentada como opciones obligatorias de producto para POS. |

| 2026-06-24 | `flutter analyze` | Sin issues despues de disponibilidad diaria de productos. |
| 2026-06-24 | `flutter test` | 53 tests pasan despues de disponibilidad diaria de productos. |
| 2026-06-24 | POS oculta ramas sin productos disponibles | Categorias/subcategorias vacias por disponibilidad diaria ya no aparecen en POS. |
| 2026-06-24 | `flutter analyze` | Sin issues despues de ocultar ramas no disponibles en POS. |
| 2026-06-24 | `flutter test` | 54 tests pasan despues de ocultar ramas no disponibles en POS. |
| 2026-06-24 | Opciones obligatorias por producto | Producto permite configurar grupos de opciones; POS solicita una opcion por grupo antes de agregar al carrito. |
| 2026-06-24 | `flutter gen-l10n` | Localizaciones regeneradas para opciones de producto. |
| 2026-06-24 | `dart run build_runner build --delete-conflicting-outputs` | Codigo Drift regenerado para `local_products.option_groups_json` y `local_sale_items.selected_options_label`; flag obsoleto reportado por build_runner. |
| 2026-06-24 | `dart format lib test` | Archivos formateados despues de opciones de producto. |
| 2026-06-24 | `flutter analyze` | Sin issues despues de opciones de producto. |
| 2026-06-24 | `flutter test` | 57 tests pasan despues de opciones de producto. |
| 2026-06-24 | Editor guiado de opciones | Formulario de producto ya no requiere sintaxis manual para grupos/opciones; se agregan y quitan desde controles visibles. |
| 2026-06-24 | `flutter analyze` | Sin issues despues del editor guiado de opciones. |
| 2026-06-24 | `flutter test` | 56 tests pasan despues del editor guiado de opciones. |
| 2026-06-24 | Selector POS de opciones | Dialogo de opciones usa botones tactiles grandes, progreso por pasos, boton anterior y avance automatico entre grupos. |
| 2026-06-24 | `flutter test test\features\pos\presentation\widgets\product_options_dialog_test.dart` | 1 test pasa para el selector POS de opciones. |
| 2026-06-24 | Separacion tactil de cuentas | Dialogo de cuentas separadas cambia desplegables por panel de pendientes, cuentas seleccionables y asignacion por toque. |
| 2026-06-24 | `flutter test test\features\pos\presentation\widgets\pos_split_accounts_dialog_test.dart` | 1 test pasa para asignacion tactil de cuentas separadas. |
| 2026-06-24 | Cobro POS guiado por metodo de pago | Referencia de pago solo aparece cuando el metodo la requiere y `Cobrar` se habilita cuando la venta esta lista. |
| 2026-06-24 | `flutter test test\features\pos\presentation\widgets\pos_cart_panel_test.dart` | 2 tests pasan para referencia de pago condicional. |
| 2026-06-24 | Limpieza de referencia POS | Al cambiar a un metodo sin referencia o completar venta, la referencia escrita se limpia para evitar datos arrastrados. |
| 2026-06-24 | Correccion responsiva de carrito POS | El total de cada linea usa ancho controlado para evitar overflow en paneles estrechos. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | Formato sin cambios pendientes. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 61 tests pasan. |
| 2026-06-24 | `tool\build_web_release.ps1` | Build Web release correcto con assets Drift copiados. |
| 2026-06-24 | Verificacion HTTP release `http://localhost:8096/` | HTTP 200 y bootstrap Flutter presente. |
| 2026-06-24 | Verificacion visual CDP `http://localhost:8096/#/pos` | POS renderiza en release; no queda pantalla blanca. |
| 2026-06-24 | Pago individual por cuenta separada | Cada cuenta separada permite metodo de pago y referencia propios; el cobro genera ventas con esos datos. |
| 2026-06-24 | Panel POS desplazable | El carrito se vuelve desplazable para evitar overflow cuando hay varias cuentas separadas. |
| 2026-06-24 | Cola de sincronizacion local | Agregado repositorio, procesador, contrato de envio remoto y enviador deshabilitado hasta configurar Supabase SmooControl. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib/features/sync, lib/core/di/service_locator.dart, test/features/sync` | Sin errores despues de cola de sincronizacion local. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test/features/sync` | 4 tests pasan para cola y procesador de sincronizacion. |
| 2026-06-24 | Roles y usuarios locales | Agregadas tablas Drift, entidades, repositorios y DI para roles, permisos, asignaciones y perfiles de usuario. |
| 2026-06-24 | `dart run build_runner build --delete-conflicting-outputs` | Codigo Drift regenerado para tablas locales de acceso; flag obsoleto reportado por build_runner. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: roles/users/base de datos` | Sin errores despues de roles y usuarios locales. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test/features/roles,test/features/users` | 3 tests pasan para roles, permisos y usuarios locales. |
| 2026-06-24 | Mantenimiento de roles y usuarios | Agregadas paginas, BLoCs, formularios y rutas sin exponer IDs internos. |
| 2026-06-24 | `flutter gen-l10n` | Localizaciones regeneradas para roles y usuarios. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: roles/users/navegacion/dashboard` | Sin errores despues de mantenimiento de roles y usuarios. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test/features/roles,test/features/users` | 5 tests pasan incluyendo BLoCs de roles y usuarios. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de roles, usuarios y sync local. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 72 tests pasan. |
| 2026-06-24 | `powershell -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto con assets Drift copiados. |
| 2026-06-24 | Verificacion HTTP release `http://localhost:8096/` | `index`, `main.dart.js`, `sqlite3.wasm` y `drift_worker.js` responden HTTP 200. |
| 2026-06-24 | Verificacion CDP release `#/roles` y `#/users` | Ambas rutas cargan Flutter en release sin excepciones runtime. |
| 2026-06-24 | Servicio de permisos | Agregado `AccessControlService` para validar permisos individuales, todos o alguno por rol. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test/features/roles` | 6 tests pasan para roles y servicio de permisos. |
| 2026-06-24 | Supabase seed alineado | Permisos remotos usan los mismos codigos que Flutter y seeds globales corrigen conflictos con indices parciales. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de servicio de permisos y ajuste Supabase. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 75 tests pasan. |
| 2026-06-24 | Semilla local de acceso | Roles, permisos y asignaciones base se crean automaticamente desde Roles o Usuarios si faltan. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test/features/roles,test/features/users` | 9 tests pasan para roles, usuarios, permisos y semilla local. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de semilla local de acceso. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 76 tests pasan. |
| 2026-06-24 | Supabase seed de permisos por rol | `seed.sql` asigna permisos base a roles globales `admin`, `cashier` y `waiter`. |
| 2026-06-24 | Auditoria local base | Agregada tabla Drift `local_audit_logs`, entidad, datasource, repositorio y DI. |
| 2026-06-24 | `dart run build_runner build --delete-conflicting-outputs` | Codigo Drift regenerado para `local_audit_logs`; flag obsoleto reportado por build_runner. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: audit/base de datos` | Sin errores despues de auditoria local. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test/features/audit` | 2 tests pasan para auditoria local. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de auditoria local base. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 78 tests pasan. |
| 2026-06-24 | Build Web offline-friendly | `tool/build_web_release.ps1` usa `--no-web-resources-cdn` para servir CanvasKit localmente. |
| 2026-06-24 | `powershell -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto con Drift y CanvasKit local. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Verificacion CDP release | Rutas `#/roles`, `#/users` y `#/pos` cargan Flutter sin excepciones runtime. |
| 2026-06-24 | Pantalla de auditoria local | Agregada ruta `#/audit`, BLoC, vista por fecha y acceso desde dashboard. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: audit/navegacion/dashboard` | Sin errores despues de pantalla de auditoria. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test/features/audit` | 4 tests pasan para repositorio y BLoC de auditoria. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de pantalla de auditoria. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 86 tests pasan. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de pantalla de auditoria. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Verificacion CDP release | Rutas `#/audit`, `#/roles`, `#/users` y `#/pos` cargan Flutter sin excepciones runtime. |
| 2026-06-24 | Auditoria aplicada a gastos | `expenses.save` y `expenses.category.save` escriben entradas en `local_audit_logs` al completar correctamente. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: expenses bloc` | Sin errores despues de conectar auditoria en gastos. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test/features/expenses` | 6 tests pasan incluyendo auditoria de gastos. |
| 2026-06-24 | Auditoria aplicada a caja/settings | `cash.open`, `cash.close` y `settings.save` escriben entradas en `local_audit_logs`. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: cash_register/settings bloc` | Sin errores despues de auditoria en caja/settings. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: cash_register/settings` | 7 tests pasan incluyendo auditoria de caja y settings. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de auditoria en caja/settings. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 88 tests pasan. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de auditoria en caja/settings. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Verificacion CDP release | Rutas `#/audit`, `#/cash-register` y `#/settings` cargaban Flutter sin excepciones runtime en esa version. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de auditoria aplicada a gastos. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 86 tests pasan. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de auditoria aplicada a gastos. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Verificacion CDP release | Rutas `#/audit`, `#/expenses` y `#/pos` cargan Flutter sin excepciones runtime. |
| 2026-06-24 | Auth base | Agregado contrato `IAuthRepository`, `DisabledAuthRepository` y `AuthBloc` para preparar Google Auth sin fingir configuracion remota. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test/features/auth` | 4 tests pasan para Auth deshabilitado y BLoC. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de Auth base. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 82 tests pasan. |
| 2026-06-24 | `powershell -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de Auth base. |
| 2026-06-24 | Verificacion HTTP release final | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Verificacion CDP release final | Rutas `#/roles`, `#/users` y `#/pos` cargan Flutter sin excepciones runtime. |
| 2026-06-24 | Auditoria aplicada a acciones sensibles | `sales.void`, `roles.save` y `users.save` escriben entradas en `local_audit_logs` al completar correctamente. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: sales/roles/users bloc` | Sin errores despues de conectar auditoria aplicada. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: sales/roles/users bloc` | 8 tests pasan incluyendo verificacion de audit logs. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de auditoria aplicada. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 84 tests pasan. |
| 2026-06-24 | `powershell -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de auditoria aplicada. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Verificacion CDP release | Rutas `#/roles`, `#/users` y `#/pos` cargan Flutter sin excepciones runtime. |
| 2026-06-24 | Auditoria aplicada a catalogos operativos | `catalog.category.save`, `products.save`, `payment_methods.save` y `tables.save` escriben entradas en `local_audit_logs`. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: catalog/products/payment_methods/tables bloc` | Sin errores despues de auditoria en catalogos operativos. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: catalog/products/payment_methods/tables bloc` | 12 tests pasan incluyendo verificacion de audit logs. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | Formato sin cambios pendientes despues de auditoria en catalogos operativos. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de auditoria en catalogos operativos. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 92 tests pasan. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto con Drift y CanvasKit local. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Pantalla de sincronizacion local | Agregada ruta `#/sync`, dashboard, BLoC y resumen de procesamiento manual. |
| 2026-06-24 | `flutter gen-l10n` | Localizaciones regeneradas para sincronizacion. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: sync/navegacion/dashboard` | Sin errores despues de pantalla de sincronizacion. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test/features/sync` | 6 tests pasan incluyendo BLoC de sincronizacion. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | Formato sin cambios pendientes despues de pantalla de sincronizacion. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de pantalla de sincronizacion. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 94 tests pasan. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de pantalla de sincronizacion. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Verificacion CDP release | Ruta `#/sync` renderiza en release sin excepciones runtime; captura guardada en `build/sync-route-check.png`. |
| 2026-06-24 | Cola sync para ventas/gastos | Ventas completadas, anulaciones y gastos operativos encolan operaciones locales para sincronizacion remota futura. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: sales/expenses/sync` | Sin errores despues de encolar ventas y gastos. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: sales_repository/expenses_repository/sync` | 9 tests pasan incluyendo verificacion de cola local. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | Formato sin cambios pendientes despues de cola sync para ventas/gastos. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de cola sync para ventas/gastos. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 94 tests pasan. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de cola sync para ventas/gastos. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Verificacion CDP release | Ruta `#/sync` renderiza en release sin excepciones runtime despues de encolar ventas/gastos. |
| 2026-06-24 | Cola sync para catalogos operativos | Categorias, productos, metodos de pago, mesas y cuentas separadas encolan operaciones locales para sincronizacion remota futura. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: catalog/products/payment_methods/tables repositories` | Sin errores despues de encolar catalogos operativos. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: catalog/products/payment_methods/tables repositories` | 5 tests pasan incluyendo verificacion de cola local. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | Formato sin cambios pendientes despues de cola sync para catalogos. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de cola sync para catalogos. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 94 tests pasan. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de cola sync para catalogos. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Cola sync para caja/settings | Apertura/cierre de caja y settings encolan operaciones locales para sincronizacion remota futura. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: cash_register/settings repositories` | Sin errores despues de encolar caja/settings. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: cash_register/settings repositories` | 3 tests pasan incluyendo verificacion de cola local. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | Formato sin cambios pendientes despues de cola sync para caja/settings. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de cola sync para caja/settings. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 94 tests pasan. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de cola sync para caja/settings. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Cola sync para roles/usuarios | Roles, permisos, asignaciones y perfiles de usuario encolan operaciones locales para sincronizacion remota futura. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: roles/users repositories` | Sin errores despues de encolar roles/usuarios. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: roles/users repositories` | 3 tests pasan incluyendo verificacion de cola local. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | Formato sin cambios pendientes despues de cola sync para roles/usuarios. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de cola sync para roles/usuarios. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 94 tests pasan. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de cola sync para roles/usuarios. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200. |
| 2026-06-24 | Cola sync para auditoria | Entradas de auditoria local encolan operaciones para sincronizacion remota futura. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: audit repository` | Sin errores despues de encolar auditoria. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: audit repository` | 2 tests pasan incluyendo verificacion de cola local. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | 273 archivos formateados, sin cambios pendientes despues de integrar cola sync amplia. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de integrar cola sync amplia. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 94 tests pasan despues de integrar cola sync amplia. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de integrar cola sync amplia. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `localhost:8096`. |
| 2026-06-24 | Opciones POS requeridas/opcionales | Los grupos de opciones de producto quedan requeridos por defecto y pueden marcarse opcionales para permitir omitirlos en POS. |
| 2026-06-24 | `flutter gen-l10n` | Localizaciones regeneradas para `optionGroupRequiredField` y `skipOptionalOptionAction`. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | 275 archivos formateados, sin cambios pendientes despues de opciones opcionales. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de opciones POS requeridas/opcionales. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 97 tests pasan incluyendo omision de grupos opcionales y compatibilidad JSON. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de opciones POS requeridas/opcionales. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `localhost:8096`. |
| 2026-06-24 | Reportes con rango personalizado | Agregada opcion `Rango` con selector de fechas libre y calculo por `ReportDateRange`. |
| 2026-06-24 | `flutter gen-l10n` | Localizaciones regeneradas para `reportPeriodCustom` y `reportSelectRange`. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | 275 archivos formateados, sin cambios pendientes despues de rango personalizado. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de rango personalizado en reportes. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 98 tests pasan incluyendo resumen por rango personalizado. |
| 2026-06-24 | Revision de limite de archivos | Test de reportes dividido en fakes; ningun archivo Dart manual supera 300 lineas. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de rango personalizado en reportes. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `localhost:8096`. |
| 2026-06-24 | Drag & drop en cuentas separadas | Productos pendientes pueden arrastrarse hacia una cuenta en pantallas grandes; se conserva asignacion por toque. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | 276 archivos formateados, sin cambios pendientes despues de drag & drop. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de drag & drop en cuentas separadas. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 99 tests pasan incluyendo asignacion por toque y drag & drop. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de drag & drop en cuentas separadas. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `localhost:8096`. |
| 2026-06-24 | PDF basico de reportes | Reportes permite compartir PDF con rango, metricas principales, caja, productos y anulaciones. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | 279 archivos formateados, sin cambios pendientes despues de PDF de reportes. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de PDF de reportes. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 100 tests pasan incluyendo generacion PDF de reportes. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de PDF de reportes. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `localhost:8096`. |
| 2026-06-24 | Estado operativo de mesas | Mesas inactivas se guardan como `disabled`; al reactivarlas vuelven a `available` si estaban deshabilitadas. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | 279 archivos formateados, sin cambios pendientes despues de estado operativo de mesas. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de estado operativo de mesas. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 102 tests pasan incluyendo estado disabled/available en mesas. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados excluidos. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de estado operativo de mesas; Windows aviso que `.dart_tool` estaba en uso al limpiar, sin afectar el build. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `localhost:8098`. |
| 2026-06-24 | Vista previa de comprobantes | Transacciones abre un visor PDF integrado por venta, con opciones de imprimir o compartir desde la vista previa. |
| 2026-06-24 | `flutter gen-l10n` | Localizaciones regeneradas para `previewPdfAction` e `invoicePreviewTitle`. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | 281 archivos formateados; un test nuevo recibio formato. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de vista previa de comprobantes. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 103 tests pasan incluyendo accion de vista previa en transacciones. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; `sales_page.dart` queda en 278 lineas y el visor PDF en 71. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de vista previa de comprobantes. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `localhost:8098`. |
| 2026-06-24 | Auditoria legible | La pantalla de auditoria traduce acciones y detalles a etiquetas de negocio, omitiendo IDs internos en la vista. |
| 2026-06-24 | `flutter gen-l10n` | Localizaciones regeneradas para etiquetas auditables y `yesLabel`/`noLabel`. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | 283 archivos formateados, sin cambios pendientes despues de auditoria legible. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de auditoria legible. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 104 tests pasan incluyendo tile de auditoria sin claves tecnicas visibles. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; auditoria queda en pagina de 104 lineas y tile de 119. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de auditoria legible. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `localhost:8098`. |
| 2026-06-24 | Sincronizacion legible | La pantalla de sincronizacion muestra modulo, operacion y estado con etiquetas de negocio, ocultando IDs locales y nombres tecnicos. |
| 2026-06-24 | `flutter gen-l10n` | Localizaciones regeneradas para operaciones/estados de sincronizacion. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | 285 archivos formateados, sin cambios pendientes despues de sincronizacion legible. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de sincronizacion legible. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 105 tests pasan incluyendo tile de sincronizacion sin IDs tecnicos visibles. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; sync queda en pagina de 91 lineas y tile de 84. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de sincronizacion legible. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `localhost:8098`. |
| 2026-06-24 | Caja obligatoria para POS | El POS bloquea el cobro si no existe caja diaria abierta; conserva el carrito y no reserva comprobante. |
| 2026-06-24 | `mcp__dart.dart_format` con `paths: lib,test` | 286 archivos formateados, sin cambios pendientes despues de caja obligatoria para POS. |
| 2026-06-24 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de caja obligatoria para POS. |
| 2026-06-24 | `mcp__dart.run_tests` con `paths: test` | 106 tests pasan incluyendo bloqueo de cobro sin caja abierta. |
| 2026-06-24 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; pruebas POS quedan divididas en archivo principal de 290 lineas y casos de caja de 38. |
| 2026-06-24 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de caja obligatoria para POS. |
| 2026-06-24 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `localhost:8098`. |
| 2026-06-25 | Unica caja abierta por dia | El repositorio bloquea abrir una segunda caja si ya existe una caja abierta para la misma fecha de negocio. |
| 2026-06-25 | `mcp__dart.dart_format` con `paths: lib,test` | 286 archivos formateados; se ajusto formato del test de doble apertura de caja. |
| 2026-06-25 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de bloquear doble apertura de caja. |
| 2026-06-25 | `mcp__dart.run_tests` con `paths: test` | 107 tests pasan incluyendo bloqueo de doble caja abierta por dia. |
| 2026-06-25 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; test de repositorio de caja queda en 188 lineas y repositorio en 157. |
| 2026-06-25 | Limpieza de Problems VS Code | Se corrigieron imports, const, orden de directivas, lambdas, argumentos redundantes, lineas largas y tipos privados expuestos en tests. |
| 2026-06-25 | `flutter analyze` | Sin issues; el panel Problems queda alineado con cero problemas del analizador. |
| 2026-06-25 | `mcp__dart.dart_format` con `paths: lib,test` | 286 archivos formateados, sin cambios pendientes despues de limpieza de Problems. |
| 2026-06-25 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de limpieza de Problems. |
| 2026-06-25 | `mcp__dart.run_tests` con `paths: test` | 107 tests pasan despues de limpieza de Problems. |
| 2026-06-25 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de limpieza de Problems. |
| 2026-06-25 | Limpieza de servidores release locales | Se detuvieron servidores Python antiguos en 8098, 8099 y 8100 para evitar verificaciones colgadas. |
| 2026-06-25 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-25 | Limpieza documental de pendientes resueltos | `FUNCTIONAL_AUDIT`, `DATABASE` y `OFFLINE_SYNC` actualizados para reflejar caja persistida, gastos asociados a caja y assets Web Drift ya validados. |
| 2026-06-25 | Operador local centralizado | Se agrego `CurrentOperatorService` para concentrar el usuario temporal usado en caja, gastos y anulaciones hasta conectar Auth real. |
| 2026-06-25 | `flutter analyze` | Sin issues despues de centralizar operador local. |
| 2026-06-25 | `mcp__dart.dart_format` con `paths: lib,test` | 288 archivos formateados, sin cambios pendientes despues de centralizar operador local. |
| 2026-06-25 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de centralizar operador local. |
| 2026-06-25 | `mcp__dart.run_tests` con `paths: test` | 108 tests pasan incluyendo `CurrentOperatorService`. |
| 2026-06-25 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas despues de centralizar operador local. |
| 2026-06-25 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de centralizar operador local. |
| 2026-06-25 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-25 | Pruebas de operador local en UI | Agregados widget tests para apertura de caja y registro de gasto usando `CurrentOperatorService`. |
| 2026-06-25 | `flutter analyze` | Sin issues despues de pruebas de operador local en UI. |
| 2026-06-25 | `mcp__dart.dart_format` con `paths: lib,test` | 290 archivos formateados, sin cambios pendientes. |
| 2026-06-25 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de pruebas de operador local en UI. |
| 2026-06-25 | `mcp__dart.run_tests` con `paths: test` | 110 tests pasan incluyendo dialogos de caja y gastos. |
| 2026-06-25 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de pruebas de operador local en UI. |
| 2026-06-25 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-25 | Limpieza de fakes POS | Fakes de pruebas POS ya no lanzan `UnimplementedError`; devuelven fallas controladas cuando la operacion no aplica. |
| 2026-06-25 | `flutter analyze` | Sin issues despues de limpiar fakes POS. |
| 2026-06-25 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de limpiar fakes POS. |
| 2026-06-25 | `mcp__dart.run_tests` con `paths: test` | 110 tests pasan despues de limpiar fakes POS. |
| 2026-06-25 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de limpiar fakes POS. |
| 2026-06-25 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-25 | Limpieza final de Problems VS Code | Se quitaron argumentos redundantes del preview PDF y variables publicas de fakes en tests para evitar API publica accidental. |
| 2026-06-25 | `flutter analyze` | Sin issues; validacion directa contra el analizador que alimenta Problems de VS Code. |
| 2026-06-25 | `mcp__dart.dart_format` con archivos afectados | 3 archivos revisados; sin cambios pendientes despues del formato. |
| 2026-06-25 | `mcp__dart.analyze_files` | Sin errores despues de limpiar Problems remanentes. |
| 2026-06-25 | `mcp__dart.run_tests` | 110 tests pasan despues de limpiar Problems remanentes. |
| 2026-06-25 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas despues de la limpieza. |
| 2026-06-25 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de limpiar Problems remanentes. |
| 2026-06-25 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-25 | QA responsivo POS | Se corrigio overflow movil en la grilla del POS y overflow tablet en el panel de cuenta; pruebas para `360x800`, `768x1024` y `1366x768`, incluyendo ocultar productos no disponibles. |
| 2026-06-25 | `flutter analyze` | Sin issues despues del ajuste responsivo POS. |
| 2026-06-25 | `mcp__dart.analyze_files` | Sin errores despues del ajuste responsivo POS. |
| 2026-06-25 | `mcp__dart.run_tests` | 113 tests pasan incluyendo QA responsivo POS. |
| 2026-06-25 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas despues del ajuste responsivo POS. |
| 2026-06-25 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues del ajuste responsivo POS. |
| 2026-06-25 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-25 | Limpieza de Problems en tests de roles/usuarios | Variables `audit` movidas a alcance local de prueba para evitar marcas de API publica en VS Code. |
| 2026-06-25 | `flutter analyze` | Sin issues despues de limpiar tests de roles/usuarios. |
| 2026-06-25 | `mcp__dart.analyze_files` con tests afectados | Sin errores en `roles_bloc_test.dart` y `users_bloc_test.dart`. |
| 2026-06-25 | `mcp__dart.run_tests` con tests afectados | 4 tests pasan para roles y usuarios. |
| 2026-06-25 | Regla ready for Supabase | `rules.md` actualizado para exigir equivalencia local/remota, payload sync, auditoria y mapeo Auth/restaurante en nuevos cambios. |
| 2026-06-25 | Auditoria ready for Supabase | Creado `Documentation/SUPABASE_READINESS_AUDIT.md` con estado listo, deuda y bloqueadores antes de remoto. |
| 2026-06-25 | Rediseño operativo POS | POS cambia a flujo tipo terminal con ticket superior, categorias principales persistentes, grilla central sin boton atras, barra inferior de cobro y controles por linea. |
| 2026-06-25 | Cambio en efectivo POS | Metodos que afectan caja solicitan recibido, calculan cambio y bloquean cobro si el recibido es menor al total. |
| 2026-06-25 | `flutter analyze` | Sin issues despues del rediseño operativo POS. |
| 2026-06-25 | `flutter test` | 115 tests pasan despues del rediseño operativo POS. |
| 2026-06-25 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues del rediseño operativo POS. |
| 2026-06-25 | `mcp__dart.run_tests` con `paths: test/features/pos` | 27 tests POS pasan despues del rediseño operativo POS. |
| 2026-06-25 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; generados quedan excluidos de la regla manual. |
| 2026-06-25 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues del rediseño operativo POS. |
| 2026-06-25 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-25 | POS tactil por franjas | POS reorganizado para tableta en ticket, productos/subcategorias, categorias, mesas y barra inferior en 3 secciones: acciones, mas opciones y metodos de pago. |
| 2026-06-25 | Metodos de pago jerarquicos | Metodos de pago ahora soportan grupo POS, moneda y orden visual; `Efectivo` puede abrir opciones como `Cordoba` y `Dolar`. |
| 2026-06-25 | Supabase ready para pagos | Migracion y seed agregan `group_name`, `currency_code` y `display_order` para metodos de pago remotos. |
| 2026-06-25 | `flutter analyze` | Sin issues despues del POS tactil por franjas. |
| 2026-06-25 | `flutter test` | 115 tests pasan despues del POS tactil por franjas. |
| 2026-06-25 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas despues del POS tactil por franjas. |
| 2026-06-25 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues del POS tactil por franjas. |
| 2026-06-25 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-25 | Categorias POS siempre visibles | Las categorias activas ya no se filtran por disponibilidad de productos; el POS muestra tambien categorias vacias. |
| 2026-06-25 | `flutter analyze` | Sin issues despues de corregir categorias visibles del POS. |
| 2026-06-25 | `flutter test test\features\pos` | 29 tests POS pasan despues de corregir categorias visibles. |
| 2026-06-25 | `flutter test` | 117 tests pasan despues de corregir categorias visibles. |
| 2026-06-25 | Prueba especifica de 3 categorias | Widget test valida que `Cafe caliente`, `Almuerzos` y `Postres` se muestren aunque dos esten vacias. |
| 2026-06-25 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de corregir categorias visibles. |
| 2026-06-25 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-25 | Quitar nivel de categoria | Catalogo permite quitar subcategorias/niveles, pide confirmacion, bloquea raiz y mueve productos/subniveles directos al padre. |
| 2026-06-25 | `flutter analyze` | Sin issues despues de quitar nivel de categoria. |
| 2026-06-25 | `flutter test test\features\catalog` | 9 tests pasan incluyendo mover productos/subniveles al padre al quitar un nivel. |
| 2026-06-25 | `flutter test` | 119 tests pasan despues de quitar nivel de categoria. |
| 2026-06-25 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de quitar nivel de categoria. |
| 2026-06-25 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Arbol contraible de categorias | Pantalla de catalogo inicia con raices contraidas y funciona como acordeon: solo una raiz abierta a la vez. |
| 2026-06-26 | `flutter analyze` | Sin issues despues del arbol contraible de categorias. |
| 2026-06-26 | `flutter test test\features\catalog` | 12 tests pasan despues del arbol contraible de categorias. |
| 2026-06-26 | Refinamiento POS de cobro tactil | Agregada franja compacta de total bajo el ticket, se reemplazan campos `Recibido`/`Cambio` por `Mas opciones` y se elimina boton separado de `Cobrar`. |
| 2026-06-26 | Flujo de pago POS por metodo | Al tocar un metodo final de efectivo se abre teclado tactil con el total precargado; `OK` valida recibido, muestra cambio y completa la venta. |
| 2026-06-26 | Documentacion POS | `SCREENS_AND_FLOWS` y `BUSINESS_RULES` actualizados para reflejar pago por botones, modal tactil y barra inferior en secciones. |
| 2026-06-26 | `flutter analyze` | Sin issues despues del refinamiento POS de cobro tactil. |
| 2026-06-26 | `flutter test test\features\pos` | 30 tests POS pasan incluyendo franja de total, `Mas opciones` y modal de monto. |
| 2026-06-26 | `flutter test` | 123 tests pasan despues del refinamiento POS de cobro tactil. |
| 2026-06-26 | Revision de limite de archivos | Archivos POS nuevos/modificados se mantienen bajo 300 lineas: acciones 272, dialogo de monto 265, ticket 235. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues del refinamiento POS. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Metodos de pago como arbol | Pagos soporta `parent_id` e `is_payment_target` para navegar `Transferencias > BANPRO > Cuenta` y cobrar solo opciones finales. |
| 2026-06-26 | Mantenimiento jerarquico de pagos | La pantalla de metodos de pago muestra arbol, selecciona ubicacion por lista y distingue grupos de navegacion contra opciones cobrables. |
| 2026-06-26 | POS con pagos multinivel | POS navega metodos de pago por niveles tactiles y mantiene fallback para datos legados basados en `group_name`. |
| 2026-06-26 | Supabase ready para pagos multinivel | Migracion y seed agregan `parent_id` e `is_payment_target` para metodos de pago remotos. |
| 2026-06-26 | `flutter gen-l10n` | Localizaciones regeneradas para mantenimiento jerarquico de pagos. |
| 2026-06-26 | `dart run build_runner build --delete-conflicting-outputs` | Codigo Drift regenerado para `local_payment_methods.parent_id` e `is_payment_target`. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de pagos jerarquicos multinivel. |
| 2026-06-26 | `flutter test test\features\payment_methods test\features\pos\presentation\widgets\pos_ready_view_test.dart` | 13 tests pasan incluyendo creacion de cuenta bajo banco y navegacion POS multinivel. |
| 2026-06-26 | `flutter test` | 125 tests pasan despues de pagos jerarquicos multinivel. |
| 2026-06-26 | Revision de limite de archivos | Archivos manuales de pagos/POS se mantienen bajo 300 lineas; `pos_payment_section.dart` queda en 252. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de pagos jerarquicos multinivel. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Quitar nivel de metodo de pago | Metodos de pago permite quitar niveles internos con confirmacion, bloquea raices y mueve hijos directos al nivel padre. |
| 2026-06-26 | `flutter gen-l10n` | Localizaciones regeneradas para confirmacion de quitar nivel de metodo de pago. |
| 2026-06-26 | `flutter test test\features\payment_methods` | 8 tests pasan incluyendo quitar nivel de pago y mover cuentas al padre. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de quitar nivel de metodo de pago. |
| 2026-06-26 | `flutter test` | 127 tests pasan despues de quitar nivel de metodo de pago. |
| 2026-06-26 | Revision de limite de archivos | Archivos de metodos de pago modificados bajo 300 lineas: pagina 221, BLoC 141, repositorio 124, datasource 76. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de quitar nivel de metodo de pago. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Correccion alta de producto con opciones | El formulario lee el estado real del editor al guardar, permite crear productos nuevos con uno o varios grupos de opciones y muestra error dentro del grupo incompleto. |
| 2026-06-26 | Claridad en grupos de opciones | El campo `Grupo` pasa a `Nombre del grupo` para evitar confundirlo con una opcion como `Guarnicion`. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de corregir alta de producto con opciones. |
| 2026-06-26 | `flutter test test\features\products` | 12 tests de productos pasan, incluyendo alta con dos grupos de opciones. |
| 2026-06-26 | `flutter test` | 130 tests pasan despues de corregir alta de producto con opciones. |
| 2026-06-26 | Revision de limite de archivos | Archivos de productos modificados bajo 300 lineas; tests de opciones separados para mantener archivos en 186 y 175 lineas. |
| 2026-06-26 | Modificadores POS reutilizables | Se agrega modulo `Modificadores POS` para administrar grupos como `Bastimento` y `Guarnicion`, asignarlos a productos y controlar disponibilidad por opcion. |
| 2026-06-26 | Supabase ready para modificadores | Migracion remota agrega `modifier_groups`, `modifier_options` y `product_modifier_groups`; seed agrega permiso `modificadores.gestionar`. |
| 2026-06-26 | `flutter gen-l10n` | Localizaciones regeneradas para el nuevo modulo de modificadores. |
| 2026-06-26 | `dart run build_runner build --delete-conflicting-outputs` | Codigo Drift regenerado para `local_modifier_groups`, `local_modifier_options` y `local_products.modifier_group_ids_json`; flag obsoleto reportado por build_runner. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de agregar modificadores POS reutilizables. |
| 2026-06-26 | `flutter test` | 131 tests pasan incluyendo resolucion POS de grupos modificadores reutilizables y ocultamiento de opciones no disponibles. |
| 2026-06-26 | Revision de limite de archivos | Ningun archivo Dart manual supera 300 lineas; DI de Auth/POS y selector de modificadores fueron extraidos a archivos pequenos. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de modificadores POS reutilizables. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Modificadores con opciones hijas claras | La pantalla muestra cantidad de opciones por grupo, agrega opciones desde el boton `+` del grupo e inactiva grupos/opciones con confirmacion. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de aclarar opciones hijas e inactivacion de modificadores. |
| 2026-06-26 | `flutter test test\features\pos test\features\products` | 44 tests pasan despues de ajustar modificadores POS. |
| 2026-06-26 | `flutter test` | 131 tests pasan despues de ajustar inactivacion y opciones hijas de modificadores. |
| 2026-06-26 | Inactivacion uniforme de catalogos | Productos, categorias de gastos, mesas, roles, usuarios, metodos de pago y modificadores tienen accion directa para inactivar con confirmacion. |
| 2026-06-26 | Quitar vs inactivar | Metodos de pago conserva `Quitar nivel` para corregir jerarquias y agrega `Inactivar` para ocultar opciones/grupos sin perder historico. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de agregar inactivacion uniforme de catalogos. |
| 2026-06-26 | `flutter test` | 131 tests pasan despues de agregar inactivacion uniforme de catalogos. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de inactivacion uniforme de catalogos. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Revision de limite de archivos | Ningun archivo Dart manual de `lib/features` supera 300 lineas despues de inactivacion uniforme de catalogos. |
| 2026-06-26 | Mesa obligatoria en POS | El POS ya no permite agregar productos sin mesa seleccionada; la fila de mesas marca visualmente la mesa activa y cada mesa conserva su cuenta. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de exigir mesa antes de cargar productos. |
| 2026-06-26 | `flutter test` | 132 tests pasan incluyendo bloqueo de productos sin mesa seleccionada. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de exigir mesa en POS. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Opciones POS sin duplicados | Si un producto tiene modificadores reutilizables, el POS usa solo esos grupos y no mezcla grupos legacy embebidos. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de corregir duplicado de grupos POS. |
| 2026-06-26 | `flutter test` | 133 tests pasan incluyendo producto con grupos legacy y modificadores reutilizables sin duplicar preguntas. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de corregir duplicado de grupos POS. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Caja por usuario desde POS | El POS consulta caja abierta del operador actual antes de operar; si no existe, muestra apertura de caja desde el POS. |
| 2026-06-26 | Cierre de caja desde POS | `Mas opciones` agrega `Cerrar caja` y usa cierre a ciegas con solo conteo fisico; `Caja diaria` queda operativa desde POS. |
| 2026-06-26 | Bloqueo de cierre con pedidos pendientes | El POS no permite cerrar caja si cualquier mesa conserva productos pendientes, aunque la mesa activa este vacia. |
| 2026-06-26 | Regla de caja por cajero | El repositorio bloquea doble caja abierta para el mismo cajero y fecha, pero permite cajas separadas de cajeros distintos. |
| 2026-06-26 | `flutter gen-l10n` | Localizaciones regeneradas para flujo de caja requerido desde POS. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de mover apertura/cierre de caja al POS. |
| 2026-06-26 | `flutter test` | 135 tests pasan incluyendo caja por cajero, caja requerida en POS y bloqueo de cierre con pedidos pendientes. |
| 2026-06-26 | Revision de limite de archivos | Ningun archivo Dart manual de `lib/features` supera 300 lineas; handlers de carrito POS extraidos a `pos_cart_handlers.dart`. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de mover caja operativa al POS. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Refinamiento de mesas POS | Mesas ocupadas se muestran primero por orden de ocupacion, libres despues ordenadas, con etiqueta `Ocupada` y color azul para seleccion. |
| 2026-06-26 | Refinamiento de cierre de caja POS | `Cerrar caja` valida pedidos pendientes al tocar el boton y ya no abre el conteo fisico si hay mesas abiertas. |
| 2026-06-26 | Refinamiento visual de pagos POS | Botones de metodos de pago quedan sin iconos para mayor limpieza tactil. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de refinar mesas, cierre de caja y botones de pago POS. |
| 2026-06-26 | `flutter test test\features\pos` | 36 tests POS pasan despues de refinar mesas y cierre de caja. |
| 2026-06-26 | `flutter test` | 136 tests pasan despues de refinar mesas, cierre de caja y botones de pago POS. |
| 2026-06-26 | Revision de limite de archivos | Ningun archivo Dart manual de `lib/features` supera 300 lineas despues del refinamiento POS. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de refinar mesas, cierre de caja y pagos POS. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Dependencia de iconos Flutter | Se agrega `cupertino_icons` para eliminar aviso de fuente faltante en build Web release. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de agregar dependencia de iconos. |
| 2026-06-26 | `flutter test test\features\pos` | 36 tests POS pasan despues de agregar dependencia de iconos. |
| 2026-06-26 | Build y verificacion release final | Build Web release correcto y assets principales responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Mensajes tactiles modales | Se agrega helper comun para mensajes con `OK` y se eliminan `SnackBar`/`ScaffoldMessenger` de `lib`. |
| 2026-06-26 | Mensaje de cierre de caja | La validacion por mesas abiertas ahora se muestra como modal tactil con boton `OK`. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de convertir mensajes operativos a modales tactiles. |
| 2026-06-26 | `flutter test test\features\pos test\features\sales test\features\settings` | 48 tests pasan despues de convertir mensajes operativos a modales tactiles. |
| 2026-06-26 | `flutter test` | 136 tests pasan despues de eliminar mensajes inferiores y usar modales tactiles. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de convertir mensajes a modales tactiles. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | Limpieza de dashboard | Se elimina la opcion independiente `Caja diaria`; caja se opera solo desde POS y sigue disponible para reportes/sync. |
| 2026-06-26 | `flutter gen-l10n` | Localizaciones regeneradas despues de eliminar textos de la pantalla independiente de caja. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de quitar ruta y pantalla `Caja diaria`. |
| 2026-06-26 | `flutter test` | 136 tests pasan incluyendo validacion de que el dashboard ya no muestra `Caja diaria`. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de quitar la pantalla independiente `Caja diaria`. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-26 | POS sin barra superior | Se oculta la barra con boton atras/titulo `Abrir POS` para ganar espacio operativo en tablet. |
| 2026-06-26 | Salir desde POS | `Mas opciones` agrega `Salir`; bloquea salida si hay mesas con productos pendientes. |
| 2026-06-26 | `flutter gen-l10n` | Localizaciones regeneradas para accion `Salir` del POS. |
| 2026-06-26 | `flutter analyze` | Sin issues despues de ocultar barra superior y agregar salida del POS. |
| 2026-06-26 | `flutter test` | 136 tests pasan despues de ocultar barra superior y agregar salida del POS. |
| 2026-06-26 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de ocultar barra superior y agregar salida del POS. |
| 2026-06-26 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Botones de cantidad POS | Los controles `+` y `-` del ticket se refinan como botones circulares medianos para uso tactil. |
| 2026-06-27 | `flutter analyze` | Sin issues despues de refinar botones de cantidad POS. |
| 2026-06-27 | `flutter test test\features\pos` | 36 tests POS pasan despues de refinar botones de cantidad. |
| 2026-06-27 | `flutter test` | 136 tests pasan despues de refinar botones de cantidad POS. |
| 2026-06-27 | Revision de limite de archivos | Ningun archivo Dart manual de `lib/features` supera 300 lineas; `pos_ticket_panel.dart` queda en 223 lineas. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de refinar botones de cantidad POS. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Separacion de cuentas refinada | Pantalla completa con panel original fijo, cuentas horizontales, nombres editables, totales, asignacion por toque/drag y retorno de items al eliminar una cuenta no confirmada. |
| 2026-06-27 | Reglas de mesas y cuentas | Documentado nombre interno vs nombre operativo, mesa original como contenedor y pendiente controlado para cuentas hijas visibles/cobrables desde fila de mesas. |
| 2026-06-27 | Supabase ready para mesas | Payload de sync de mesas/cuentas cambia a `snake_case` y se documenta `display_name` como nombre operativo temporal. |
| 2026-06-27 | Limpieza tecnica POS | Eliminado archivo obsoleto `pos_split_accounts_panels.dart`; separacion usa el nombre operativo de mesa en pantalla. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de refinar separacion y payload de mesas. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos,test/features/tables` | 45 tests pasan despues de refinar separacion y mesas. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 137 tests pasan despues de refinar separacion, mesas y payload Supabase-ready. |
| 2026-06-27 | Revision de limite de archivos | Archivos tocados bajo 300 lineas: dialogo 238, workspace 287, items 119, repositorio de mesas 129. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de refinar separacion y mesas. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Acciones dentro de separacion | `Confirmar`, `Cancelar` y `+` se mueven dentro del panel de orden original, respetando el modelo visual definido. |
| 2026-06-27 | Cuentas hijas visibles en POS | Al confirmar separacion, las cuentas hijas quedan almacenadas por mesa y se muestran inmediatamente junto a la mesa original en la fila de mesas. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de mover acciones y mostrar cuentas hijas junto a la mesa. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos` | 39 tests POS pasan incluyendo cuentas hijas junto a la mesa original. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 139 tests pasan despues de refinar separacion y cuentas hijas. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de mover acciones y mostrar cuentas hijas. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Limpieza de Problems VS Code | Corregidos tipado dinamico en fila de mesas, parametro obsoleto en separacion de cuentas y lint de cascada en handlers POS. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de limpiar Problems reportados por VS Code. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos` | 39 tests POS pasan despues de limpiar Problems reportados por VS Code. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 139 tests pasan despues de limpiar Problems reportados por VS Code. |
| 2026-06-27 | Revision de limite de archivos | Archivos tocados bajo 300 lineas: `pos_tables_band.dart` 231, `pos_split_accounts_workspace.dart` 243, `pos_cart_handlers.dart` 142. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de limpiar Problems reportados por VS Code. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Bug critico separacion/cobro | Mesa original dividida queda como contenedor no cobrable; las cuentas hijas se seleccionan y cobran una por una. |
| 2026-06-27 | Estado de cuentas hijas | Se conserva internamente la orden fuente, se vacia la mesa original y se carga solo la cuenta hija seleccionada. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de corregir cobro duplicado de mesa dividida. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos` | 41 tests POS pasan incluyendo mesa original vacia, seleccion de cuenta hija y cobro parcial. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 141 tests pasan despues de corregir cobro de cuentas separadas. |
| 2026-06-27 | Revision de limite de archivos | Archivos tocados bajo 300 lineas: `pos_state.dart` 300, `pos_checkout_handlers.dart` 189, `pos_split_checkout_handlers.dart` 129, `pos_tables_band.dart` 262. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de corregir cobro de cuentas separadas. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Limpieza de documentacion publica POS | `PosReady` se mueve a `pos_ready_state.dart` con documentacion publica completa para eliminar los 18 Problems de `public_member_api_docs`. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de documentar `PosReady` y mantener archivos bajo 300 lineas. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos` | 41 tests POS pasan despues de corregir los Problems de documentacion publica. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de limpiar Problems de documentacion publica. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Separacion de cuentas tactil | Pantalla ajustada para tablet: paneles responsivos, seleccion multiple visible, movimiento entre original e hijas, hijas entre si y validaciones como modal `OK`. |
| 2026-06-27 | Botonera en orden original | `Confirmar`, `Cancelar` y `+` usan colores diferenciados y el boton de agregar ya no queda vacio. |
| 2026-06-27 | Campo nombre de cuenta | Etiqueta y texto del nombre de cuenta quedan legibles sobre el panel oscuro. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de refinar separacion de cuentas tactil. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos` | 44 tests POS pasan despues de refinar separacion de cuentas. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 144 tests pasan despues de refinar separacion de cuentas. |
| 2026-06-27 | Revision de limite de archivos | Archivos tocados bajo 300 lineas: `pos_split_accounts_dialog.dart` 232, `pos_split_accounts_workspace.dart` 292, `pos_split_accounts_header.dart` 131, `pos_split_accounts_items.dart` 134. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de refinar separacion de cuentas. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Regla UI sin truncamiento | Documentado que botones de accion no pueden truncar texto y que textos sugeridos en campos deben ser placeholders. |
| 2026-06-27 | Separacion sin valores prellenados | Las cuentas nuevas muestran `Cuenta 1`, `Cuenta 2` como placeholder; al confirmar se usa el placeholder si el usuario no escribe nombre. |
| 2026-06-27 | Botonera separacion refinada | `Confirmar` usa texto corto sin ellipsis y el boton de agregar cuenta muestra un solo `+`. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de aplicar regla de placeholders y botones sin truncamiento. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos/presentation/widgets/pos_split_accounts_dialog_test.dart` | 7 tests pasan incluyendo placeholders en cuentas generadas. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos` | 45 tests POS pasan despues del refinamiento de separacion. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 145 tests pasan despues del refinamiento de separacion. |
| 2026-06-27 | Revision de limite de archivos | Archivos tocados bajo 300 lineas: `pos_split_accounts_workspace.dart` 268, `pos_split_accounts_dialog.dart` 237, `pos_split_accounts_header.dart` 133, `pos_split_account_name_input.dart` 49. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de corregir truncamiento y placeholders en separacion. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Paleta centralizada | Agregado `AppSemanticColors` en `core/theme` para tokens operativos de POS, mesas, separacion y acciones peligrosas. |
| 2026-06-27 | Colores UI sin hardcode | Reemplazados `Color(0x...)` y `Colors.*` en `features`/`core/design_system` por `ColorScheme` o `context.semanticColors`. |
| 2026-06-27 | L10n y Design System | Eliminado `Confirmar` hardcodeado y agregado `confirmAction`; `AppText` acepta estilo semantico y `AppButton` evita truncamiento por ellipsis. |
| 2026-06-27 | Documentacion de tema | `ARCHITECTURE.md` documenta que la paleta vive en `core/theme` y que pantallas no deben definir colores directos. |
| 2026-06-27 | Auditoria textual de rules | Sin `Color(0x...)`, `Colors.*` ni `Confirmar` hardcodeado en `features`/`core/design_system`. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de centralizar paleta. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos` | 45 tests POS pasan despues de centralizar paleta y fallback semantico. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 145 tests pasan despues de centralizar paleta. |
| 2026-06-27 | Revision de limite de archivos | Archivos tocados bajo 300 lineas: `app_semantic_colors.dart` 166, `app_theme.dart` 27, `app_text.dart` 70, `app_button.dart` 55, `pos_tables_band.dart` 268, `pos_split_accounts_header.dart` 130, `modifier_group_tile.dart` 190. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release limpio despues de detener servidor y centralizar paleta. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Paleta oficial Ivory Premium | Agregado `AppPalette` con la paleta nueva y reemplazado el `ColorScheme` viejo por fondo ivory, superficies calidas, texto cafe oscuro y acentos premium. |
| 2026-06-27 | Semantica visual actualizada | `AppSemanticColors` ahora deriva de `AppPalette` para acciones peligrosas, seleccion de mesas, estados ocupados y separacion de cuentas. |
| 2026-06-27 | Auditoria de colores anteriores | Sin rastros de los hex viejos `006A60`, `8B4B00`, `BA1A1A`, `FAFCF8`, `191C1B`, `E886D5`, `DCA0D9`, `BFEA80`, `E8F4FF`, `7A3434`, `6F4545` ni `246B9F` en `lib`. |
| 2026-06-27 | Colores directos concentrados | `Color(0x...)` queda solo en `lib/core/theme/app_palette.dart`; no hay `Colors.teal`, `Colors.green`, `Colors.red`, `Colors.blue`, `Colors.purple`, `Colors.orange` ni `Colors.brown` en `lib`. |
| 2026-06-27 | Limpieza de Problems de paleta | Corregido orden de constructor, referencia de comentario y longitud de linea en `app_semantic_colors.dart`; `flutter analyze` queda sin issues. |
| 2026-06-27 | Salida POS con pendientes | Eliminado bloqueo que impedia salir del POS con mesas abiertas; `Cerrar caja` conserva validacion de pendientes. |
| 2026-06-27 | Regla minima para separar cuentas | `Separar cuentas` muestra modal y no abre division cuando la mesa tiene una sola unidad de producto. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos/presentation/widgets/pos_ready_view_test.dart` | 9 tests pasan incluyendo salida con pendientes y bloqueo de division con una unidad. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de ajustar salida POS y validacion minima de division. |
| 2026-06-27 | `flutter analyze` | Sin issues despues de ajustar salida POS y validacion minima de division. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos` | 47 tests POS pasan despues de ajustar salida y division minima. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 147 tests pasan despues de ajustar salida POS y division minima. |
| 2026-06-27 | Persistencia de pedidos abiertos POS | Agregada tabla local `local_pos_open_ticket_lines` para conservar pedidos por mesa al salir y volver al POS. |
| 2026-06-27 | `dart run build_runner build --delete-conflicting-outputs` | Drift regenerado para schema local v12; build_runner ignora flag obsoleto. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de agregar persistencia local de pedidos abiertos. |
| 2026-06-27 | `flutter analyze` | Sin issues despues de agregar persistencia local de pedidos abiertos. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos` | 48 tests POS pasan incluyendo restauracion de mesa al reingresar al POS. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 148 tests pasan despues de agregar persistencia local de pedidos abiertos. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de agregar persistencia local de pedidos abiertos. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Teclados tactiles globales | Agregados dialogos reutilizables numerico y texto para campos operativos del POS, caja, pagos y separacion de cuentas. |
| 2026-06-27 | POS sin dependencia de teclado fisico | Referencias de pago, monto recibido, nombres de cuentas separadas y apertura/cierre de caja usan campos solo lectura con teclado modal tactil. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de agregar teclados tactiles globales. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test/features/pos,test/features/cash_register` | 55 tests pasan despues de adaptar los flujos tactiles de POS y caja. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 148 tests pasan despues de agregar teclados tactiles globales. |
| 2026-06-27 | Revision de limite de archivos | Sin archivos manuales mayores a 300 lineas en `core/design_system`, `features/pos` y `features/cash_register`. |
| 2026-06-27 | `flutter analyze` | Sin issues despues de agregar teclados tactiles globales. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de agregar teclados tactiles globales. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-27 | Seguridad tactil POS | Acciones destructivas `Limpiar`, quitar linea de ticket y quitar cuenta separada piden confirmacion antes de modificar el pedido. |
| 2026-06-27 | `mcp__dart.analyze_files` con `paths: lib,test` | Sin errores despues de proteger acciones destructivas del POS. |
| 2026-06-27 | `flutter analyze` | Sin issues despues de proteger acciones destructivas del POS. |
| 2026-06-27 | `mcp__dart.run_tests` con `paths: test` | 150 tests pasan despues de agregar confirmaciones tactiles. |
| 2026-06-27 | Revision de limite de archivos | Sin archivos manuales mayores a 300 lineas en `core/design_system` y `features/pos`. |
| 2026-06-27 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de proteger acciones destructivas del POS. |
| 2026-06-27 | Verificacion HTTP release | `index`, `main.dart.js`, `sqlite3.wasm`, `drift_worker.js` y `canvaskit.js` responden HTTP 200 en `127.0.0.1:8101`. |
| 2026-06-28 | Login local operativo | Agregado acceso por correo y PIN con creacion inicial de administrador, hash con salt y seleccion de destino por rol. |
| 2026-06-28 | Operador autenticado | `CurrentOperatorService` usa la sesion local para caja, gastos, ventas y auditoria; `usuario-local` queda como fallback legacy/test. |
| 2026-06-28 | Usuarios con PIN | La pantalla de usuarios permite crear/cambiar PIN; en edicion, PIN vacio conserva el existente. |
| 2026-06-28 | Drift schema v14 | `local_user_profiles` agrega `pin_salt` y `pin_hash` para login local offline. |
| 2026-06-28 | `flutter analyze` | Sin issues despues de implementar login local. |
| 2026-06-28 | `flutter test` | 156 tests pasan despues de implementar login local y ajustar flujo de salida POS por rol. |
| 2026-06-28 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto con login local; Flutter solo advierte `--pwa-strategy` deprecado y paquetes con versiones nuevas. |
| 2026-06-28 | Permisos activos por ruta | Agregado `RouteAccessGuard`; dashboard filtra modulos y las rutas bloquean acceso manual sin permiso. |
| 2026-06-28 | Usuario POS | `local_user_profiles.is_pos_user` permite dirigir usuarios operativos directo al POS sin exponerles el panel completo. |
| 2026-06-28 | Permisos nuevos | Agregados `configuracion.gestionar` y `auditoria.ver`; la semilla agrega permisos faltantes sin resetear roles existentes. |
| 2026-06-28 | `flutter analyze` | Sin issues despues de activar guardas de permisos y usuario POS. |
| 2026-06-28 | `flutter test` | 156 tests pasan despues de activar guardas de permisos y usuario POS. |
| 2026-06-28 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de activar guardas de permisos y usuario POS. |
| 2026-06-28 | Transacciones de caja desde POS | `Mas opciones > Ver Transacciones` muestra ventas cobradas en la caja abierta del usuario actual. |
| 2026-06-28 | Tasas de cambio | Agregado catalogo `Tasas de cambio` con permiso `tasas.gestionar`, edicion por dia y aplicacion de una tasa a todo el mes. |
| 2026-06-28 | Cobro POS en USD | El POS convierte recibido extranjero con la tasa del dia, bloquea si falta tasa y muestra vuelto en moneda local. |
| 2026-06-28 | Drift schema v16 | Agregada tabla local `local_exchange_rates` y regenerado codigo Drift. |
| 2026-06-28 | `flutter gen-l10n` | Localizaciones regeneradas para tasas de cambio, transacciones de caja y mensajes de tasa faltante. |
| 2026-06-28 | `dart run build_runner build --delete-conflicting-outputs` | Drift regenerado para schema local v16; build_runner ignora flag obsoleto. |
| 2026-06-28 | `flutter analyze` | Sin issues despues de agregar transacciones POS y tasas de cambio. |
| 2026-06-28 | `flutter test` | 156 tests pasan despues de agregar transacciones POS y tasas de cambio. |
| 2026-06-28 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de agregar transacciones POS y tasas de cambio. |
| 2026-06-28 | Verificacion HTTP release | `http://127.0.0.1:8101/` responde HTTP 200 despues del build release. |
| 2026-06-28 | Productos visibles al navegar POS | Si la seccion de productos esta oculta, seleccionar categorias la vuelve a mostrar automaticamente. |
| 2026-06-28 | Boton premium de productos POS | `Ocultar Productos`/`Mostrar Productos` pasa a boton con icono, superficie y estado de accion clara. |
| 2026-06-28 | Tasa visible en POS | La franja del total muestra `Tasa de cambio del dia` con valor o estado no configurado. |
| 2026-06-28 | `flutter analyze` | Sin issues despues de ajustar visibilidad de productos, boton premium y tasa visible en POS. |
| 2026-06-28 | `flutter test` | 156 tests pasan despues de ajustar visibilidad de productos, boton premium y tasa visible en POS. |
| 2026-06-28 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de ajustar la franja del total POS. |
| 2026-06-28 | Verificacion HTTP release | `http://127.0.0.1:8101/` responde HTTP 200 despues del build release. |
| 2026-06-28 | Categorias de gastos agrupables | `local_expense_categories.parent_id` permite grupos como administrativos o combustible y categorias registrables hijas. |
| 2026-06-28 | Gastos como mantenimiento de catalogo | La pantalla `Gastos` deja de mostrar `Gastos de hoy` y queda enfocada en gestionar categorias de gasto. |
| 2026-06-28 | Registrar gasto desde POS | `Mas opciones > Registrar Gasto` abre flujo tactil por grupos/categorias y guarda el gasto asociado a la caja abierta. |
| 2026-06-28 | Reporte dedicado de gastos | Reportes agrega detalle de gastos por periodo con filtro por categoria. |
| 2026-06-28 | Drift schema v17 | Agregado `parent_id` a `local_expense_categories` y regenerado codigo Drift. |
| 2026-06-28 | `dart run build_runner build --delete-conflicting-outputs` | Drift regenerado para schema local v17; build_runner ignora flag obsoleto. |
| 2026-06-28 | `flutter analyze` | Sin issues despues de refinar costos, gastos POS y reporte de gastos. |
| 2026-06-28 | `flutter test` | 156 tests pasan despues de refinar costos, gastos POS y reporte de gastos. |
| 2026-06-28 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de refinar costos y registro de gastos desde POS. |
| 2026-06-28 | Verificacion HTTP release | `http://127.0.0.1:8101/` responde HTTP 200 despues del build release. |
| 2026-06-28 | Eliminar categorias de gasto | Mantenimiento de gastos cambia inactivar por eliminar; si se elimina un grupo, sus hijas pasan a raiz. |
| 2026-06-28 | Gasto POS tactil | Registro de gasto desde POS usa teclado numerico tactil para monto y teclado tactil de texto para descripcion. |
| 2026-06-28 | Pantalla gasto POS responsiva | La pantalla `Registrar Gasto` usa grilla de tiles con altura estable y colores de la paleta para tableta tactil. |
| 2026-06-28 | `flutter analyze` | Sin issues despues de eliminar categorias de gasto y refinar registro tactil POS. |
| 2026-06-28 | `flutter test` | 158 tests pasan despues de eliminar categorias de gasto y refinar registro tactil POS. |
| 2026-06-28 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de eliminar categorias de gasto y refinar registro tactil POS. |
| 2026-06-28 | Verificacion HTTP release | `http://127.0.0.1:8101/` responde HTTP 200 despues del build release. |
| 2026-06-28 | Franja total POS refinada | Boton de productos reducido a `Ocultar`/`Mostrar` con color de paleta; tasa compacta queda junto al total de `Monto`. |
| 2026-06-28 | `flutter gen-l10n` | Localizaciones regeneradas para etiquetas compactas de productos y tasa POS. |
| 2026-06-28 | `flutter analyze` | Sin issues despues de refinar boton de productos y posicion de tasa POS. |
| 2026-06-28 | `flutter test` | 158 tests pasan despues de refinar boton de productos y posicion de tasa POS. |
| 2026-06-28 | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1` | Build Web release correcto despues de refinar la franja del total POS. |
| 2026-06-28 | Verificacion HTTP release | `http://127.0.0.1:8101/` responde HTTP 200 despues del build release. |
| 2026-06-28 | Supabase remoto SmooControl | CLI enlazada al proyecto `hexejdgbcmyiyqtvfihr` en East US (Ohio), separado de `MemberShip`. |
| 2026-06-28 | Migracion remota Supabase | `001_initial_schema.sql` aplicada correctamente al proyecto remoto SmooControl. |
| 2026-06-28 | Seed remoto Supabase | `seed.sql` aplicado con roles, permisos, metodos de pago y categorias de gasto base; permisos alineados con la app. |
| 2026-06-28 | Validacion remota Supabase | 23 tablas publicas creadas, RLS habilitado en 23/23 y `supabase db lint --linked --schema public` sin errores. |
| 2026-06-28 | Permiso de modificadores | App local alinea `modificadores.gestionar` con seed remoto y ruta `Modificadores POS`. |
| 2026-06-28 | `flutter analyze` | Sin issues despues de alinear permisos y aplicar Supabase remoto. |
| 2026-06-28 | `flutter test test\features\roles test\app_test.dart` | 9 tests pasan despues de alinear permisos con Supabase. |
| 2026-06-30 | Cierre go-live Supabase/POS | Documentado checklist de salida a produccion, rescate desde remoto, prueba offline y reglas para actualizar APK sin perder datos. |
| 2026-06-30 | Validacion final y APK release | `flutter analyze --no-pub` sin issues, `flutter test --reporter=compact` con 189 tests correctos, APK `release/SmooControl-produccion.apk` generado y verificado con firma v2. |
| 2026-06-30 | Inventario simple V1.1 | Productos agregan `Controla inventario`; stock vive en tablas separadas y el POS descuenta/reintegra por movimientos auditables al cobrar/anular. |
| 2026-06-30 | Drift schema v19 | Agregadas tablas `local_inventory_stock`, `local_inventory_movements` y columna `local_products.tracks_inventory`; codigo Drift regenerado. |
| 2026-06-30 | Supabase inventario | Agregada migracion `005_simple_inventory.sql` con `products.tracks_inventory`, `inventory_stock`, `inventory_movements` y RPC idempotente `apply_inventory_movement`. |
| 2026-06-30 | Auditoria inventario/sync | El pull de stock preserva movimientos locales pendientes de ventas/anulaciones antes de sobrescribir con Supabase. |
| 2026-06-30 | Supabase inventario endurecido | Migracion `006_harden_inventory_sync.sql` valida restaurante, producto, tipo y cantidad dentro de la RPC `apply_inventory_movement`. |
| 2026-06-30 | Validacion auditoria inventario | `flutter analyze --no-pub` sin issues, `flutter test --reporter=compact` con 196 tests correctos, build Web release correcto y `supabase db lint --linked --schema public` sin errores. |
| 2026-07-01 | Incidente APK release sin internet | Documentada causa raiz: permiso `android.permission.INTERNET` faltaba en `android/app/src/main/AndroidManifest.xml`; checklist exige validar permisos del APK final con `aapt dump permissions`. |
| 2026-07-02 | Sync POS por dispositivo | `Sincronizar datos` desde POS baja catalogo por RPC `pos_pull_operational_catalog` usando `syncDeviceId`/`syncDeviceSecret`; ya no depende de sesion activa de administrador remoto. |
| 2026-07-02 | Catalogo POS movil | Subcategorias y productos usan minimo dos columnas en superficies de telefono para evitar una sola columna y mejorar navegacion tactil. |
| 2026-07-02 | Validacion sync/catalogo POS | `flutter analyze`, `supabase_catalog_pull_service_test`, `supabase_sync_remote_sender_test`, `device_initialization_service_test` y `pos_ready_view_test` pasan despues de los ajustes. |

## Riesgos Activos

| Riesgo | Estado | Mitigacion |
| --- | --- | --- |
| MCP Dart puede operar sobre rutas no deseadas si se ejecuta sobre toda la raiz | Controlado | Registrar raiz y acotar herramientas Dart MCP a `lib` y `test` cuando sea posible. |
| Proyecto Supabase de produccion MemberShip | Controlado | No enlazar ni ejecutar migraciones contra ese proyecto. |
| Persistencia Web Drift requiere assets wasm/worker | Controlado | `web/sqlite3.wasm` y `web/drift_worker.js` agregados; despues de cada build release deben existir tambien en `build/web`. |
| Pantalla blanca por plugins Web de Supabase/passkeys | Controlado | `supabase_flutter` removido hasta implementar Auth/Supabase completo; se elimino `passkeys_web` del bundle. |
| Formularios con campos tecnicos expuestos | Controlado | Catalogo, Productos, Gastos, Caja, POS y Ventas corregidos en UI inicial; IDs y relaciones internas se gestionan por sistema. |
| Sincronizacion remota sin proyecto Supabase SmooControl | Controlado | La cola local existe, pero el enviador remoto falla explicitamente hasta configurar el proyecto remoto nuevo. |
| Desarrollo local no alineado a Supabase remoto | Controlado | Nueva regla ready for Supabase y auditoria obligatoria antes de migracion remota. |
