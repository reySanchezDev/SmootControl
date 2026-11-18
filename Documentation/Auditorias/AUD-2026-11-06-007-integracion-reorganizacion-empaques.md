# AUD-2026-11-06-007 — Integración y flujos para reorganizar Empaques

**Fecha:** 2026-11-06. **Estado:** auditoría estática de integración y propuesta de mitigaciones; **NO IMPLEMENTADO**.  
**Repositorio:** `reySanchezDev/SmootControl`; código examinado: `develop/backoffice-stabilization-integration`, SHA `7ce5163e0c6e698397dca0f57689966a4b714649`. La pantalla del usuario muestra la UI Executive Ivory de `Empaques` con tres pestañas: Tipos de venta, Empaques y Reglas.  
**Alcance:** navegación, permisos, escritura administrativa, catálogos, POS, consumo/reversión de empaques, inventario, descarga remota, cola, ventas, anulaciones, contratos SQL, transición a Centro de Artículos y configuración de modalidades/terminales.  
**Límites:** no se ejecutaron tests, migraciones, builds ni consultas al Supabase desplegado; no se inspeccionaron exhaustivamente los cuerpos de todas las migraciones; documentar como *riesgo* cualquier comportamiento no confirmado.

## Resumen ejecutivo y decisión

**No mover tres pestañas simplemente cambiando rutas.** Actualmente `PackagingPage` orquesta **cuatro catálogos remotos en una carga conjunta** (tipos, empaques, reglas, productos) y edita tres entidades que el POS offline consume por ID. **La separación debe ser de navegación/UX antes que de persistencia**: reutilizar temporalmente tablas, UUID, repositorios y RPC, insertar destinos nuevos, ejecutar equivalencia y retirar la ruta antigua solo después de aprobar regresión. El motor de empaques no es genérico: solo consume si el código del tipo de venta es literalmente `to_go` (detalle crítico confirmado).

**Destino recomendado:**
- Configuración → **Modalidades de servicio** (`sales_types` reutilizable, predeterminada global temporal).
- Configuración → **Dispositivos POS** (después de proyecto terminales: N:M permitidos/default por dispositivo).
- Centro de Artículos → filtro **Empaques** (`packaging_items` sin crear IDs nuevos).
- Ficha del producto → **Empaque y consumo** (`product_packaging_rules` filtradas por producto); mantener vista administrativa transversal para reglas masivas/diagnóstico si hace falta, sin duplicar autoridad.
- Inventario → pestaña Empaques y compras de lotes **permanecen**.
- Ruta `/packaging` queda como alias/redirect funcional temporal; retirarla solo tras telemetría, permisos y smoke de deep links/workspace.

## Mapa real de dependencias

| ID | Trayecto / contrato | Evidencia inspeccionada | Severidad si se rompe | Mitigación |
|---|---|---|---|---|
| I-01 | Pantalla → lectura de 4 conjuntos | `packaging_page.dart`: `_loadSnapshot` ejecuta `getSalesTypes, getPackagingItems, getRules, getProducts`, falla completa si uno falla | ALTO | Separar carga por destino; estados de error locales, spinner por panel, refresco tras guardar, protección a carreras y filtros |
| I-02 | Formularios / interacción | `packaging_tabs_part.dart`, `packaging_dialogs_part.dart`: crear/editar, default, activo, cantidad y asociaciones | ALTO | Reusar lógica y validaciones; tests widget CRUD; preservar selection toolbar y UX sin «... Más» |
| I-03 | Ruta e integración Backoffice | `app_routes.dart` `/packaging`; `app_router.dart` crea `PackagingPage`; `app_route_experience.dart` autoriza experiencia Backoffice; `_requiresOnlineAdmin` y workspace | ALTO | Crear rutas nuevas, actualizar catalogación de rutas/guards y sidebar/workspace; alias legacy protegido; probar tab abierto/deep link/signout |
| I-04 | Permisos | `route_access.dart`: `/packaging` acepta **cualquiera** de `empaques.gestionar` / `tipos_venta.gestionar`, pero pantalla incluye ambas y reglas | **CRÍTICO de autorización** | Cada destino debe tener permiso exacto; acciones/endpoint también; probar roles parciales; auditar RLS y RPC, no confiar en nav |
| I-05 | Escrituras Backoffice | `supabase_admin_repository_packaging_part.dart`: `_upsert` REST a `sales_types`, `packaging_items`, `product_packaging_rules` por `restaurant_id` | ALTO | Mantener entidades y scope inicialmente; nuevas vistas utilizan mismo repo; endurecer operación atómica/default y validación cruzada |
| I-06 | Global default | SQL 009: `UNIQUE INDEX sales_types_one_default_idx ON sales_types(restaurant_id) WHERE is_default`; local repositorio desmarca anteriores, **remoto Admin guarda solo fila por upsert** | **ALTO; comportamiento a probar** | Simular cambio A→B: posible conflicto por índice si B se marca default antes de desmarcar A; RPC transaccional autorizada; conservar fallback global hasta terminales |
| I-07 | Tipos de venta ↔ reglas | SQL 009: `product_packaging_rules.product_id`, `sales_type_id`, `packaging_item_id`, `quantity_per_unit`, `is_active`; unique por combinación | CRÍTICO | No renombrar IDs/duplicar entidades; migración 1:1, controlar integridad y referencias huérfanas en copia |
| I-08 | **Consumo real condicionado por código** | `local_packaging_support_part.dart` `_salesTypeConsumesPackaging` retorna `salesType.code.toLowerCase() == 'to_go'` | **CRÍTICO: hueco funcional** | Cambiar en fase separada a regla explícita por modalidad/servicio, no derivar de código. Ensayar DELIVERY/PICKUP/DRIVE_THROUGH, `to_go` y legacy. NO activar nuevos tipos sin resolverlo |
| I-09 | Regla de empaque efectiva | `_requiredPackagingByItem` selecciona por producto + tipo + activo y multiplica por cantidad; `applySaleMovements` en datasource | CRÍTICO | Mantener semántica y unidades; pruebas combos, varias líneas iguales, cambio de modalidad, inactivo, cero reglas |
| I-10 | Atomicidad local venta+empaque | `local_sales_datasource.dart` guarda venta/ítems/movimientos de empaque en transacción Drift; `local_packaging_support_part.dart` evita repetir por `movement.id` | CRÍTICO | No sacar movimientos de esa transacción, jamás descontar desde UI; conservar IDs deterministas por venta/empaque |
| I-11 | Stock insuficiente | `local_packaging_movements_part.dart` y `local_packaging_support_part.dart` comprueban inventario de empaque con `PackagingStockException` | CRÍTICO | Bloquear o manejar según política explícita, sin fallbacks silenciosos; pruebas 0, exacto, múltiple y no-tracked |
| I-12 | Anulación | `applySaleVoidMovements` crea reversión a partir de movimientos **originales** (`packaging_sale_void`), no reglas vigentes | CRÍTICO | Conservar ledgers y costo original; no reconstruir por nueva ficha del producto |
| I-13 | Compra/stock de empaque | `inventory_stock_tabs_part.dart` muestra stock; compras batch remotas; `packaging_stock`, `packaging_movements` en SQL 009 | ALTO | Mantener páginas y flujos de compra y reportes; mover catálogo no cambia historial ni stock |
| I-14 | Pull remoto + Drift | `supabase_catalog_pull_service_inventory_part.dart`: aplica `sales_types`, empaques, reglas, saldo y preserva `_pendingPackagingDeltasByItem` | **CRÍTICO** | No cambiar claves/formatos; pruebas offline con movimientos pendientes antes/durante/después del pull; migraciones aditivas |
| I-15 | Falta de registros en pull | `supabase_catalog_pull_service_missing_part.dart` marca tipos/empaques/reglas ausentes como inactivos, no borra | ALTO | Cambiar filtro por terminal no debe hacer que datos no autorizados «desaparezcan» y se desactiven como eliminados; separar **catálogo completo** de **modalidades permitidas por terminal** |
| I-16 | Cola y contrato de sync | `supabase_sync_remote_sender.dart`, `..._payloads_part.dart`, `sales_repository_sync_support.dart`: `sales_types`, `packaging_items`, `product_packaging_rules`, `packaging_movements` y ventas | CRÍTICO | Contratos backward-compatible; reintentos idempotentes; preservar `packagingMovements` y `inventoryMovements` en ventas antiguas; revisar RPC final real |
| I-17 | Selección POS | `pos_start_handlers.dart`: carga tipos activos del catálogo y default global; `pos_ticket_sales_type_controls.dart`: chips de todos los activos | ALTO | Primero reorganizar UI Admin conservando POS; terminal default/filtro en proyecto específico con pruebas; no mezclar fases |
| I-18 | Orden abierta → modalidad | `pos_cart_handlers.dart`: guarda `salesTypeId` por clave de orden/mesa; `pos_checkout_handlers.dart`: registra `salesTypeId, salesTypeName` en venta | CRÍTICO | Restauración de tickets viejos, cambio tipo antes de pagar, mesa/cuentas separadas; snapshots históricos |
| I-19 | SQL/RLS y nuevas operaciones | `009_sales_types_packaging.sql`: RLS, FKs, únicos y permisos; backend Admin usa REST con sesión | CRÍTICO | Auditar `USING/WITH CHECK`, FKs *same-restaurant*, test permisos por RPC/tabla; no relajar políticas por nueva UI |
| I-20 | Compatibilidad con Centro de Artículos | `products` y `packaging_items` **son entidades físicas distintas**; `LocalProducts` vs `LocalPackagingItems` | CRÍTICO en migración de datos | UX maestro virtual unificado primero; no unificar tablas sin migración/ledger planificados y prueba sobre copia |
| I-21 | Defaults y desactivaciones retroactivas | UI permite inactivar sales type/empaque/regla; POS filtra, pero tickets históricos almacenan referencias | ALTO | Restricciones de uso, preview de dependencias, avisos claros; no borrar tipo ni empaque históricamente usado |
| I-22 | Disponibilidad estacional y stock | Diseño V1 establece reglas temporales y agotamiento separados; implementación real POS tiene filtro por stock | ALTO | No introducir condicionamiento estacional en el refactor de navegación; dejar interfaces compatibles y pruebas aparte |

### Hallazgos prioritarios que no deben ocultarse

**H1 — Motor no genérico para nuevas modalidades (CRÍTICO).** En `local_packaging_support_part.dart`, `_salesTypeConsumesPackaging` solo retorna true cuando el código es `to_go`. En consecuencia, la mera creación de tipo `DELIVERY` o `PICKUP` y su regla asociada **no garantiza que Kivo descuente empaque**. Antes de ampliar modalidades, corregir motor mediante política explícita y pruebas de compatibilidad, sin cambiar semántica legacy hasta validar.

**H2 — Predeterminado remoto potencialmente conflictivo (ALTO).** En tabla remota existe índice parcial único por restaurante; `saveSalesType` de Backoffice hace upsert de una fila y no desmarca atómicamente anterior. **Hipótesis verificable**: al marcar otro `is_default` puede fallar por colisión. No afirmar defecto confirmado sin test real; diseñar RPC transaccional + fallback a POS viejo.

**H3 — Permisos en ruta compartida (CRÍTICO).** `RouteAccess.anyPermissionsFor('/packaging')` da acceso con cualquiera de dos permisos, mientras la página renderiza los tres editores. Puede haber exposición de funciones UI a roles con permiso parcial; comprobar enforcement remoto y separar guard por acción en nueva navegación.

**H4 — Pull específico por dispositivo vs desaparición de elementos (CRÍTICO futuro).** La función que marca faltantes inactivos podría confundir **no autorizado para esta terminal** con **eliminado del catálogo**, si un futuro pull filtra tablas globales por terminal. Contrato correcto: catálogo completo global + vista de configuración efectiva/permisos del terminal separada y versionada.

**H5 — Centro de Artículos no es migración de tablas aprobada.** El futuro listado de empaques puede usar una proyección de `packaging_items` conservando UUID. Renombrar o fusionar `packaging_items` con `products` ahora rompería ventas, ledger, compras y reglas.

**H6 — Riesgo de carga acoplada.** Si falla `getProducts` la página completa no muestra siquiera `Tipos de venta`. Separar vistas reduce este acoplamiento, pero hace necesarias pruebas de refresh cruzado cuando se edita un producto desde otra pestaña.

## Flujos end-to-end que deben mantenerse

**F-01 Configurar tipo:** Backoffice `getSalesTypes/saveSalesType` → SQL `sales_types` → RPC catálogo POS/pull → `LocalSalesTypes` → default y chips → ventas `sales_type_id/name`.

**F-02 Configurar empaque:** Backoffice `getPackagingItems/savePackagingItem` → `packaging_items` → pull → `LocalPackagingItems` → compra/stock → motor de empaque → ledgers de venta.

**F-03 Crear regla:** Backoffice `getProducts/getSalesTypes/getPackagingItems/getRules/saveRule` → `product_packaging_rules` → pull → `LocalProductPackagingRules` → venta con tipo activo → consumo por artículo y cantidad.

**F-04 Venta y anulación:** selección tipo por orden abierta → guardar venta + ítems + consumos en transacción → queue con `packagingMovements` → sync RPC → anular reproduciendo reversa original, no regla editada.

**F-05 Refresh con venta pendiente:** POS desconectado descuenta 2 cajas → sincroniza catálogos antes de subir venta → saldo remoto se combina con deltas pendientes → subida idempotente → reconcilia cantidades.

**F-06 Separación comercial:** abrir Modalidades (permiso exacto) / Artículos filtro Empaques / Producto→Reglas; cada pantalla distinta recupera y conserva la misma fila física, UUID, formato y política de auditoría. Ruta original pasa a redirección hasta que todos los destinos funcionen.

## Plan de transición con gates y simulaciones (sin implementación autorizada)

| Etapa | Cambio permitido en una futura ejecución | Simulación o prueba obligatoria | Gate |
|---|---|---|---|
| E0 | Auditoría y snapshot read-only del estado real | Conteos y FKs, IDs, tipos `to_go`/otros, reglas huérfanas, defaults, permisos, config POS, versiones reales de migración | G0-A |
| E1 | Mock/UX de tres destinos sobre datos sintéticos | Prototipo interactivo: crear/editar empaque, tipo, regla desde producto, permisos y mensajes; comparación operación actual vs nueva | G1-A |
| E2 | Introducir rutas/vistas nuevas **con mismos repositorios y tablas** | Widget + navigation/deep links + roles parciales + workspace tabs y responsive; mantener `/packaging` | G2-A |
| E3 | Integrar editor de reglas en ficha del producto, lista Empaques virtual | CRUD y carga independientes, igualdad de IDs/reglas, refresh entre pantallas, errores parciales | G3-A |
| E4 | Correcciones aisladas de negocio: empaque explícito por modalidad, default remoto atómico | Test SQL/Drift por entrega/recoger/to_go, reversión y FIFO; compatibilidad legacy | G4-A |
| E5 | Conectar terminales N:M y modalidad efectiva — **depende del proyecto terminales y gates G-NUM/G-CON** | Multiterminal offline y dos defaults distintos, roles, sync, no falsos faltantes en pull | G5-A |
| E6 | Retirar tabs legacy con redirect/rollout gradual y feature flag | E2E integral antes y después, canario y reversión a interfaz anterior sin cambiar esquema | G6-A |

**No unir E2 con E4/E5 en el mismo commit**: navegación UX y reglas de cobro deben tener revisiones, pruebas y rollbacks independientes.

## Matriz de simulaciones y aceptación

| Caso | Esperado |
|---|---|
| Tipo actual `to_go` con 2 productos, 3 cajas por unidad | Consumo exacto; revertir exactamente las mismas cantidades |
| Nuevo tipo `delivery` con reglas | Consumo correcto **solo después** de introducir política explícita; antes, prueba debe documentar el hueco |
| `dine_in` sin regla | 0 consumo, y comprobante y venta correctos |
| Cambiar default global A→B | Exactamente uno por restaurante; no falla por `UNIQUE`; POS legacy conserva fallback |
| Usuario solo `tipos_venta.gestionar` | Administra solo modalidades, no crea empaque/regla ni accede por ruta legacy a lo no permitido |
| Usuario solo `empaques.gestionar` | Administra solo empaques/reglas dentro de sus permisos, no altera modalidades |
| Editar regla desde producto; abrir catálogo general de reglas | Mismo UUID, mismo contenido, sin duplicación; captura completa del contexto |
| Cambiar regla después de una venta y luego anular | Se reintegra costo y cantidad originales |
| Intentar inactivar empaque con órdenes pendientes | Validación o política explícita, no pérdida silenciosa de movimientos |
| Caja A sin red, venta con empaque; pull luego | Deltas locales preservados, reenvío 1 vez, sin saldo corrupto |
| Catálogo remoto filtrado para terminal | Elementos del restaurante no se marcan inactivos por no ser permitidos en esa terminal |
| Dividir cuentas y cobrar por partes | Consumo por venta/cuenta aplicable y sin duplicados |
| Multiusuario backoffice editando regla | Detectar conflictos y evitar actualización silenciosa |
| Nueva UI y ruta legacy | Permisos, deep links, tabs, navegación, selección y acciones funcionan |
| Compra empaque tras mover catálogo al maestro | Stock y movimientos sin cambio de identidad |
| Restaurar APK/DB Drift previa | Sin pérdida de `LocalPackaging*`, colas y catálogos |
| Restablecer UI por feature flag | Sin revertir migraciones ni perder registros nuevos |

**Pruebas:** integrar suite existente de POS, ventas, inventory/sync, Backoffice workspace/access; añadir tests nuevos de empaques (no se localizaron archivos `test/features/packaging` en árbol examinado), property tests para movimientos idempotentes y test SQL sobre clon. Establecer base real de tests antes de citar conteos. No afirmar suite ejecutada.

## Condiciones para aprobar reordenamiento

- Ningún ID de `sales_types`, `packaging_items`, `product_packaging_rules` ni movimiento histórico cambia.
- Misma venta y empaque: idénticas cantidades, costos e IDs de movimientos antes/después para catálogo legacy.
- Ninguna acción administrativa queda expuesta por permiso de ruta distinto del derecho de negocio real.
- Ausencia de duplicados al guardar predeterminado, compra, venta, anulación o reintentos.
- Pull con actualización parcial no invalida elementos válidos ni destruye movimientos pendientes.
- Navegación y diseño accesibles, acciones explícitas, sin «... Más» para funciones esenciales.
- Pruebas E2E y rollback de UI en staging; aprobación visual por el usuario.
- Confirmar versiones reales de Supabase y rama de deployment antes de cualquier migración; mantener G-NUM y G-CON como gates del proyecto terminales.

## Próximo paso recomendado

**E0: snapshot y prueba de equivalencia de comportamiento actual en clon aislado**. Capturar conteos de reglas por `sales_type.code`, defaults, uso de empaque, stock, integridad referencial, permisos y compatibilidad de POS offline; generar acta `Documentation/Auditorias/FasesEmpaques/FE-E0-<fecha>.md`. Ejecutar únicamente con autorización específica. La presente auditoría es **solo estática** y sus hallazgos prioritarios sirven para organizar la investigación.

## Ejecución parcial de E0 — 2026-11-06
- [Acta FE-E0-2026-11-06](FasesEmpaques/FE-E0-2026-11-06.md): línea base del esquema versionado y matriz de 12 flujos; simulación sintética de seis escenarios acorde con condicional `to_go`, **no test real del POS**.
- **G0-A pendiente:** falta consultar Supabase desplegado, clonar DB/Drift y ejecutar regresión con evidencias. No pasar a E1/E2 ni declarar integración certificada.
- Norma central QuantixEngineeringStandar v0.1.6: **ENG-008/UX-041**, IDs internos autogenerados, invisibles en UI; preservar UUID físicos al reorganizar catálogos. Los códigos `dine_in`/`to_go` no son PKs.


## Seguimiento de ejecución — 2026-11-08 (PR #17)

**Estado:** la reorganización visual acordada está implementada en `feature/articles-packaging-final-ux`, pendiente de pruebas de Codex y aprobación visual del usuario. Esta nota complementa, sin reescribir, la auditoría histórica original.

- Catálogos → **Productos** presenta una sola lista virtual de `products` (productos de venta, materias primas) y `packaging_items` (empaques); filtros por tipo, selección y CRUD en los repositorios originales, conservando IDs.
- **Configuración** contiene Modalidades de servicio y Reglas de consumo. La ficha del producto ofrece acceso contextual a sus reglas sin cambiar tabla o identidad.
- Las antiguas rutas siguen funcionando como acceso de compatibilidad; menú no duplica módulos de Empaques en Catálogos.
- Las pruebas, permisos, revisión visual y build local exigidos están documentados en `Documentation/Auditorias/FasesEmpaques/FE-E9-2026-11-08-catalogo-unificado-final.md`.
- No se ha fusionado a `main`, aplicado a producción ni certificado `flutter analyze`; no se debe presentar el cambio como comercialmente cerrado hasta recibir la aprobación del usuario.
