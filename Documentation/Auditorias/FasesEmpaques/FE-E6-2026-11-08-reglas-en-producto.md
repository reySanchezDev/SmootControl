# FE-E6 — Reglas de empaque desde ficha del producto

Fecha: 2026-11-08. Rama: `feature/product-packaging-rules-editor`.  
**Estado: código publicado en GitHub, pendiente de compilación, pruebas widget y QA visual. NO aprobado para producción.**

## Base

Parte de `fix/packaging-legacy-route-isolation` @ `a85eeb5896479697d20535ceb1d8be26d4caede3`. Laboratorio Supabase 87/87 migraciones; suite Codex: widget 4/4, navegación 10/10, Backoffice 35/35, ventas 23/23, inventario 7/7, sync 48/48. `flutter analyze` no concluyó por bloqueo local del analysis server.

## Cambio implementado

- En la ficha **editar producto existente**, aparece sección **Empaque y consumo** únicamente si el actor Backoffice dispone de `empaques.gestionar` (o admin). No se presenta a roles solo `productos.gestionar` ni a creación nueva sin producto persistido.
- El acceso queda inhabilitado si el formulario del producto tiene cambios pendientes, para evitar mezclar dos escrituras independientes.
- Diálogo de reglas del producto: lectura de `getRules/getSalesTypes/getPackagingItems`, filtro por `product.id`; crear y editar con `saveRule` existente; modalidades y empaques se eligen por nombre, nunca mostrando UUID.
- Mantiene identidad `rule.id` en edición; nuevas reglas reciben UUID desde `Uuid.v4()` del sistema, conforme ENG-008. Duplicado `(product_id,sales_type_id,packaging_item_id)` se impide en UI, y también se mantiene constraint SQL.
- Los cambios de reglas no guardan ni cambian datos del producto; los errores remotos se muestran al usuario. No hay migraciones SQL ni cambios de motor POS.
- El acceso UI está filtrado por permiso y los 85–87 RLS/triggers ya comprobados en laboratorio son la autoridad final.

## QA pendiente (obligatorio antes de cierre)

1. `dart format`, `dart analyze`, `flutter analyze`, test widget de ficha + diálogo y suite anterior. Corregir problemas reales de compilación/layout.
2. Probar rol admin, solo productos, solo empaques y permisos revocados durante sesión; realizar realmente CREATE/UPDATE de regla via REST con JWT del usuario apropiado. No usar service_role para probar autorización.
3. Producto existente con/sin reglas; reglas activas/inactivas, cambio de modalidad y empaque, validación de cantidad, duplicado, nombres, carga fallida. Producto nuevo no debe mostrar editor.
4. Confirmar que no es posible seleccionar otro producto desde el diálogo, no se alteran UUID, y el stock de una venta y su anulación siguen según regla original.
5. UX responsive en Backoffice desktop y móvil; acciones siempre explícitas, sin menú «Más»; disposición con teclado/zoom y estados de carga/error.
6. La pantalla de `Reglas de empaque` transversal debe seguir mostrando los mismos registros, sin duplicación.
7. No reconstruir Docker ni ejecutar `supabase db reset`; comprobar puerto loopback, 87/87 migraciones, Tentrix y 17 stashes.
8. Hay un **riesgo conocido**: la lógica de permiso UI se consulta en apertura del editor, no subscrita continuamente a cambios de rol. Backend debe seguir rechazando cada escritura al revocar permisos. Validar cierre/reapertura y sesión.
9. No declarar QA visual aprobado por simulación; corresponde al usuario.

## Validación Codex

Fecha: 2026-11-08. Worktree aislado: `SmooControl-product-packaging-rules-lab`.

- Base verificada: `4c01949140195e28546a1f291c46c27d9aadc2be`. Se preservaron los
  17 stashes, `main`, los worktrees existentes y las localizaciones generadas.
- `dart format` se ejecutó sobre el lote y se repitió tras las correcciones.
  No se modificaron SQL, migraciones, POS, repositorios ni permisos.
- Se agregaron pruebas widget del acceso y editor: producto nuevo sin sección,
  visibilidad por `empaques.gestionar`, estado deshabilitado con cambios
  pendientes, filtrado por `product.id`, creación, edición/identidad, rechazo de
  duplicados, ausencia de UUID visibles y error remoto sin diálogo de éxito.
  Resultado: 8/8.
- Se corrigieron dos defectos reproducibles: el editor enviaba un `Future` como
  callback de `setState`, y el estado de prueba accedía al repositorio del
  service locator aunque se hubieran inyectado loaders aislados. Se corrigieron
  de forma acotada, sin alterar el flujo predeterminado.
- Regresión: Productos 17/17; navegación 8/8; Design System/Backoffice 35/35;
  Ventas 23/23; Inventario 7/7; Sincronización 48/48.
- Laboratorio Supabase: REST HTTP 200, API `127.0.0.1:54321`, PostgreSQL
  `127.0.0.1:54324`, 87 migraciones (`087`). CRUD local con JWT sintético
  autorizado POST/PATCH/DELETE aprobado y fila eliminada; usuario solo de
  modalidades y usuario sin permiso rechazados sin filas creadas. No se usó
  producción ni se ejecutaron resets.
- `dart analyze` y `flutter analyze --no-pub` volvieron a bloquearse sin salida
  ni diagnóstico. Se registró el análisis aislado del lote con el mismo
  comportamiento; los procesos propios fueron detenidos selectivamente. No se
  declara el análisis aprobado.
- No se ejecutó QA visual autenticado ni se certificó la pantalla transversal
  mediante navegador. El consumo, stock y anulación quedan cubiertos por la
  suite de Ventas existente, no por escrituras reales adicionales.

## Diagnostico del analisis en Windows

- Verificado en `feature/product-packaging-rules-editor` @ `e0a08609abe00e3b9ea1599ad4454a381df227bc` sin modificar los tres archivos de localizacion generados.
- Herramientas: Flutter 3.41.7, Dart 3.11.5, Java 17.0.18, Android SDK 36.0.0; `flutter doctor -v` solo reporta licencias Android pendientes.
- Un proyecto Dart minimo creado en `%TEMP%` completo `dart analyze --format machine` con codigo 0.
- En Kivo, `dart analyze --format machine` y `flutter analyze --no-pub` permanecieron sin salida diagnostica. La salida de Flutter quedo en `Analyzing SmooControl-product-packaging-rules-lab...` y el proceso no termino dentro del limite controlado.
- No habia otro analysis server concurrente ni raices de paquetes faltantes: `.dart_tool/package_config.json` resolvio 142 paquetes y 0 raices inexistentes. El arbol observado fue el unico `flutter_tools -> dart -> analysis_server`; el servidor alcanzo aproximadamente 362 MiB de memoria con actividad baja antes de ser detenido selectivamente.
- No se borraron caches, instalaciones ni carpetas compartidas. No se pudo demostrar bloqueo de antivirus o archivo mediante herramientas disponibles. La causa exacta interna del bloqueo queda no determinada; el hecho reproducible es especifico del proyecto Kivo.
- Procedimiento reproducible: desde este worktree ejecutar `dart analyze --format machine` o `flutter analyze --no-pub`; si permanece en `Analyzing...`, registrar el arbol de procesos y detener solo el arbol hijo de ese comando. El analisis no debe marcarse como aprobado mientras no devuelva codigo de salida.

## Restricciones

## Preview Web local para QA

- Fecha: 2026-11-08. Worktree: `SmooControl-product-packaging-rules-lab`; SHA servido: `61af278cb719698fd25bb9703be255bcc3f64070`.
- Supabase local verificado en `127.0.0.1:54321`, PostgreSQL en `127.0.0.1:54324` y 87 migraciones aplicadas. La configuracion Web se inyecto solo mediante `--dart-define` durante el proceso, usando valores sinteticos del laboratorio; no se guardaron ni imprimieron.
- Se levanto Flutter Web en modo desarrollo sobre `http://127.0.0.1:8092/`, sin usar `tool/build_web_release.ps1` ni modificar los previews 8080/8081.
- Comprobaciones HTTP: `/`, `/flutter_bootstrap.js`, `/main.dart.js`, `/drift_worker.js` y `/sqlite3.wasm` respondieron 200. Los assets Drift/SQLite estuvieron disponibles y el HTML no contenia el mensaje de Supabase no configurado.
- No se ejecutaron operaciones CRUD automaticas. No hay navegador controlable disponible en esta sesion, por lo que login administrativo, carga inicial del Backoffice y QA visual no quedan certificados; el propietario debe abrir la URL y autenticarse con el administrador sintetico del laboratorio.
- Procedimiento reproducible: desde este worktree obtener `supabase status --output json` y el primer `public.restaurants.id` local solo en memoria; ejecutar `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8092` con `SMOO_SUPABASE_URL`, `SMOO_SUPABASE_PUBLISHABLE_KEY` y `SMOO_RESTAURANT_ID` como defines; comprobar los cinco recursos HTTP anteriores sin registrar los defines.

No fusionar PR, no publicar, no tocar `main`, datos reales, Tentrix ni producción. La futura política de consumo por pedido (bolsa única) se diseña aparte; el editor actual configura consumo por unidad de producto.
