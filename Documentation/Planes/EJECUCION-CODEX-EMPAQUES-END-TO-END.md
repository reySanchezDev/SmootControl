# PLAN RECTOR VIVO — Core de artículos de Kivo

**Identificador:** KIVO-ITEM-CORE  
**Última actualización:** 2026-11-10  
**Estado:** F0/G0 CERRADO; F1 DISEÑO Y BORRADOR DDL NO EJECUTABLE VERSIONADOS; G1 ABIERTO; MIGRACIÓN 088 CONGELADA; PANTALLAS NO AUTORIZADAS  
**Repositorio:** `reySanchezDev/SmootControl`  
**Documento único de planificación:** este archivo. Se actualiza en cada avance, sin crear un plan por PR/fase.

> **REGLA INNEGOCIABLE:** No se considerará implementado un maestro único porque dos tablas aparezcan juntas en una pantalla, en una vista SQL UNION, o por crear una tercera tabla que reciba copias sincronizadas. Solo se cumple cuando `items` es la **única autoridad de los datos maestros**, los servicios operativos usan `item_id`, las relaciones operativas y la sincronización futura son coherentes y no existe escritura funcional paralela definitiva.

## 1. Decisión técnica ratificada

Kivo adoptará el principio de **catálogo maestro único de artículos** usado por Business Central/LS Central, **sin copiar su esquema físico ni su complejidad**.

La auditoría de Codex en la carpeta de Drive `POS` — `00-fuentes-y-alcance.md`, `01-resumen-arquitectura-items.md`, `02-auditoria-integral-items-ls.md` — distingue código AL, SQL observado e inferencias. En AL/tabla 27 se observó el tipo `Item Type`; en SQL se observó el catálogo común y relaciones de BOM, vinculados y modificaciones. No se certificaron las semánticas precisas de todas las opciones y empaques de LS: Kivo deberá decidirlas y probarlas por separado.

**Modelo de negocio definitivo:**

- **`items`**: única entidad maestra y única identidad de un artículo por restaurante; código comercial único dentro del restaurante, nombre, estado, atributos comerciales y fiscales necesarios. Identificador técnico UUID inmutable y generado por el sistema; nunca pedirlo al usuario.
- **Tipo técnico** (obligatorio): `inventory`, `non_inventory`, `service`. Determina si puede tener movimientos de inventario, tratamiento de costo y validaciones contables; su cambio está restringido cuando hay movimientos/documentos incompatibles.
- **Clasificación funcional** (separada de tipo): producto vendible, ingrediente, empaque, material de consumo y otras categorías reales. Una clasificación puede ser una relación N:M mediante `item_classifications`; **no atar toda la capacidad comercial a un enum excluyente**. Un mismo artículo puede venderse, comprarse y consumirse como componente o empaque según reglas.
- **Capacidades explícitas**: vendible, comprable, aparece en POS, consumible en receta, control de inventario, bloqueos de venta/compra, activo. Validar combinaciones (servicio no genera existencias físicas; empaque puede ser inventariable o no).
- **Unidades**: `item_units` referidas a unidad base, compra y venta con conversión exacta y validaciones de magnitudes. La descripción no determina equivalencia.
- **Precio/costo**: costos y precios del artículo, preparación para listas de precios y vigencias; los valores de ventas contabilizadas deben mantener snapshots históricos.
- **Inventario**: un **libro lógico autoritativo** de movimientos con `item_id`, restaurante, ubicación, unidad base, cantidad, costo y origen/idempotencia; saldo derivado/materializado del libro, no campo fuente en `items`. No se duplican movimientos existentes.
- **Relaciones separadas por dominio**: receta y componentes, reglas contextuales de consumo/empaque, artículos vinculados/adicionales, opciones/modificadores, menú POS, ventas y cocina. Todas las referencias nuevas a artículos utilizan `item_id`; no duplicar nombres/costos como fuente actual, salvo snapshots históricos necesarios en transacciones.
- **Seguridad**: multiempresa por `restaurant_id`, FKs tenant-consistentes, RLS y validación de permisos backend en operaciones directas y RPC `SECURITY DEFINER`.

**NO hacer:** `packaging_items` como segundo maestro permanente, maestros en espejo indefinido, identificadores duplicados, saldos autoritativos separados, deducciones por texto «EMPAQUE», políticas solo en Flutter o pantallas que oculten deuda de schema.

### Ejemplos normativos

| Artículo | Tipo | Clasificaciones/capacidades | Inventario |
|---|---|---|---|
| Bolsa para delivery | inventory | empaque, comprable, consumible | sí |
| Servilleta sin kardex | non_inventory | empaque, consumible | no |
| Carne | inventory | ingrediente, comprable, consumible en receta | sí |
| Bebida embotellada | inventory | vendible y, si aplica, componente | sí |
| Hamburguesa preparada | según política de stock | vendible, receta | conforme configuración |
| Servicio de envío | service | vendible, no físico | no |

## 2. Auditoría de estado inicial (no confundir con implementación final)

Migraciones SQL versionadas 001–087: `products`, `packaging_items`, inventarios `inventory_*` y `packaging_*`, `product_packaging_rules`, `sale_items`, recetas, ventas y sincronización poseen FKs y contratos propios. En el laboratorio se reportaron 87/87 migraciones antes del trabajo de maestro; **confirmar el estado real nuevamente antes de cualquier aplicación**.

- Rama `feature/articles-packaging-final-ux` / PR #17: construyó **catálogo visual virtual** de productos y empaques. No satisface el core maestro.
- Rama `feature/item-master-db-foundation` / PR #18: propuso migración `088_item_master_foundation.sql` con backfill, triggers legacy → items, y vistas de stock/movimientos. **NO constituye la arquitectura final**: mantiene escrituras legadas como autoridad y un espejo de tercera tabla. **Congelada; no ejecutar, desplegar ni fusionar** mientras se define su sustitución.
- Las auditorías AUD-007 y FE-E1…FE-E10 son **evidencia histórica**, no órdenes operativas vigentes que puedan reemplazar este plan. Los resultados probados de RLS, autenticación, POS y packaging siguen siendo activos valiosos, no justificación para saltar gates de unificación.
- No asumir que la 088 no está aplicada: Codex debe consultar el ledger `supabase_migrations.schema_migrations` y objetos de schema de la instancia local. Si ya está aplicada, **prohibido editarla y reaplicarla silenciosamente**: preparar migración compensatoria/aditiva según la realidad, con backup y pruebas.

## 3. Modelo de datos objetivo (contratos, no DDL aprobado)

```text
restaurants
  └── items (PK item_id, UNIQUE restaurant + business_code)
        ├── item_categories / item_classifications
        ├── item_units (base, purchase, sale, conversion)
        ├── item_prices (policy, channel, effective dates)
        ├── item_inventory_policies (cost method, negative stock, reorder)
        ├── recipe_components (parent_item_id, component_item_id, version)
        ├── consumption_rules (context, source_item_id?, consumed_item_id, qty, unit)
        ├── linked_items / modifiers (explicit item references)
        ├── menu_items (item_id, visibility by channel/terminal)
        ├── sale_lines (item_id + immutable transaction snapshot)
        └── item_ledger_entries (item_id, location, qty, cost, source, idempotency)
              └── item_stock_balance (projection, never competing authority)
```

Este diagrama es la dirección de arquitectura. **Cada tabla se introducirá solo cuando la auditoría de dependencias y las necesidades de Kivo lo requieran**; prohibido crear tablas vacías por imitar LS Central.

**Reglas críticas:** toda operación que cambie inventario debe ser transaccional e idempotente; anulación revierte movimientos originales, no recalcula reglas actuales; receta y modificador preservan versión/snapshot; ventas, cocina y POS no consumen saldos ajenos a la contabilidad; códigos comerciales no son UUID; recursos cross-tenant nunca se enlazan.

## 4. Fases secuenciales y gates obligatorios

| Fase | Entregable verificable | Gate de salida |
|---|---|---|
| **F0. Censo y contrato del core** | Auditoría real de BD local: conteos, entidades, PK/FK, rutas de escritura, RPC, POS/Drift/offline, consumo/void, roles; modelo relacional final, mapa de compatibilidad, plan de migración y rollback | **G0:** evidencias SQL y diseño firmes; sin migraciones aplicadas y sin UI |
| **F1. Maestro autoritativo** | SQL migratorio sobre laboratorio que establece `items` como única autoridad; categorías/capacidades/unidades esenciales; migración de artículos existentes con claves, configuraciones esenciales y controles coherentes; contratos sin escrituras maestras paralelas | **G1:** integridad 1:1, todas las clases/tipos, RLS por rol/tenant, CRUD, sin divergencia ni duplicados |
| **F2. Inventario y relaciones operativas** | Convertir ledgers, compras, recetas, reglas, líneas de venta y sync a referencias canónicas de artículos; compatibilidad temporal con clientes POS antiguos; retiro medible de rutas legadas | **G2:** consistencia de saldos de apertura del nuevo corte, costo, compra, venta, receta, empaques, anulación, reenvío y offline posteriores al corte; concurrencia y rollback |
| **F3. Interfaz sobre core aprobado** | Único formulario/listado de artículos, filtros y validaciones de capacidades, reglas en Configuración, sin maestro alternativo oculto | **G3:** UX autenticada aprobada por propietario, pantallas con CRUD real, responsive, permisos y accesibilidad |
| **F4. Despliegue controlado** | Migraciones productivas con snapshots/backup, plan de rollout y rollback; monitoreo POS multiversión | **G4:** autorización explícita, comprobación de integridad en staging y ensayo de reversión; nunca desplegar por aprobar solo UI |

**Alcance solicitado ahora:** F0 y F1 de base de datos. **Prohibido comenzar F3/pantallas** por tener una proyección funcional o un build correcto. F2 se planifica desde F0 para que F1 no produzca deuda estructural; se ejecuta antes de considerar la unificación operativa completa.

## 5. Estrategia de migración segura (debe convertirse en checklist ejecutable en F0)

1. Capturar esquema y datos del laboratorio **read-only**, versión exacta, preflight de IDs, duplicados, códigos, referencias cruzadas, precio/costo/unidades y ledger; guardar conteos e indicadores, jamás secretos. **Se permite descartar historia operativa del laboratorio** para un nuevo baseline con datos sintéticos, previa evidencia del alcance; no existe autorización para borrar producción.
2. Enumerar **cada escritor**: REST, RPC, triggers, Drift local, offline queue, pull, transacciones POS, web admin y servicios. Inventariar rutas que escriben `products` y `packaging_items`; ninguna puede quedar como autoridad definitiva paralela.
3. Elegir UUID técnico estable para cada artículo vigente y migrar los maestros/configuraciones aún útiles. Los documentos y movimientos **históricos del laboratorio no son requisito**: pueden descartarse bajo un corte de pruebas controlado; no generar adaptadores complejos para historiales que se decidió no retener. No resolver colisiones a ciegas.
4. Crear el core canónico y migrar relaciones. Durante coexistencia, **solo un dueño de escritura por dato** y adaptadores explícitos versionados para clientes anteriores; compatibilidad con caducidad y condición de retiro. Evitar doble escritura bidireccional y loops de trigger.
5. Stock: en el laboratorio se podrá iniciar un ledger canónico vacío o registrar **asientos de apertura** de existencias verificadas; nunca copiar movimientos viejos y apertura por el mismo saldo. Desde el corte, cada movimiento tiene ID/idempotencia únicos y toda anulación revierte movimientos originales.
6. Validar SECURITY DEFINER, RLS, roles parciales, otro restaurante, JWT de test y ausencia de bypass por RPC/triggers; validar restricciones del tipo Servicio frente al inventario.
7. Probar bajo transacciones de rollback y datasets sintéticos, luego pruebas POS/sync reales locales; no hacer `supabase db reset`, no tocar producción ni Tentrix.
8. Al cerrar cada gate, actualizar **este mismo archivo** con SHA, entorno, conteos, pruebas verificadas, fallos, riesgo y decisión. No crear otro plan. Evidencias técnicas específicas podrán permanecer en auditorías históricas, sin reemplazar el estado rector.

## 6. Criterios de aceptación no negociables

- Una única autoridad real de alta/edición de artículos (no UNION visual, no espejo definitivo).
- UUID y códigos de **artículos vigentes** preservados cuando sean coherentes; si se decide recodificar, mantener correspondencia explícita de maestros y comunicar el corte. Historias de ventas/movimientos previas del laboratorio son prescindibles.
- Empaques y materias primas son artículos ordinarios; tipo inventario/no inventario se combina con capacidades/roles independientes; Servicio no genera stock físico.
- FK y RLS multiempresa para cualquier relación; sin permisos concedidos por mostrar un menú.
- Movimientos, saldos, costos, recetas, ventas, reversión, consumo y sincronización **posteriores al corte** coherentes e idempotentes.
- No se debe dejar POS viejo escribiendo simultáneamente al esquema nuevo sin un contrato de compatibilidad verificado; en laboratorio se admite reinstalar/resetear base local de terminales de prueba para adoptar el modelo canónico. En producción, la estrategia de rollout debe garantizar que no se pierdan **ventas abiertas o colas pendientes**.
- No se fusiona `main`, despliega ni retira tablas hasta autorizarlo tras pruebas.
- Prohibido afirmar completado por número de migraciones, HTTP 200, tests focalizados o ausencia de errores en widgets.
- Si `flutter analyze` permanece inconcluso, registrar el hecho: no certificarlo por sustitución con build Web.

## 7. Control de cambios y avance — actualizar EN ESTE ARCHIVO

| Fecha | Etapa | Referencia | Evidencia | Resultado / gate |
|---|---|---|---|---|
| 2026-11-06 | Auditoría inicial empaques | AUD-007 | Separación original de entidades/UX; riesgos de venta, RLS y sync | Histórico; no representa nuevo core |
| 2026-11-08 | Catálogo visual de Artículos | PR #17, `d9a4db62000d6cb88a9cc119ef337abfa53971f6` | Codex informó 126/126 tests focalizados, build Web y preview 8092 | **Solo UX/proyección**, no core |
| 2026-11-10 | Propuesta maestro espejo | PR #18 / migración 088 | Tabla nueva + triggers sobre fuentes legadas, sin auditoría real del lab aquí | **CONGELADA / NO APROBADA** |
| 2026-11-10 | Auditoría externa LS Central | Drive carpeta POS, 4 ficheros | `Item` AL tabla 27; SQL BOM, vinculados, modificadores; límites expresos | **Decisión core único ratificada** |
| 2026-11-10 | Plan rector actualizado | este documento | Objetivo autoritativo, gates F0–F4, no maquillaje UI | **F0 PENDIENTE** |\n| 2026-11-10 | Ajuste de alcance y auditoría de impacto | este documento / ADR-002 | Historia operativa del laboratorio no se conserva; clasificación de tablas, FKs, RPC, Drift, POS y estrategia de corte; script read-only ampliado | **F0 ESTÁTICA AVANZADA** |\n| 2026-11-10 | Auditoría real F0 y revisión del gate | `57d96aa995edfd704c62c31dccb6fb82f83c3690` | 55 relaciones, 143 FK, 70 funciones, 165 dependencias legacy; 8 preflights sin bloqueantes; 088 ausente | **G0 APROBADO SOLO PARA DISEÑO DE F1; migración NO autorizada** |\n| 2026-11-10 | Diseño técnico F1 | Sección 10 del plan rector | Modelo de tablas/constraints, autoridad RPC, permisos, migración coordinada F1/F2, tests y puntos de corte | **Diseño especificado** |\n| 2026-11-10 | Borrador DDL para inspección F1 | `supabase/design/ITEM_CORE_F1_DDL_DRAFT.sql` | 7 tablas canónicas, restricciones tenant, índices, RLS lectura; sin RPCs, backfill ni efectos en BD | **No ejecutado; G1 pendiente** |

### Plantilla obligatoria de actualización

Al completar trabajo, editar la fecha/estado de cabecera, la fila de fase y añadir una línea aquí con: `fecha | fase | rama/SHA | schema/migraciones | tests con conteos y exit codes | anomalías | gate/decisión | siguiente trabajo permitido`. No inventar aprobaciones ni abrir otro plan. Si hay decisión de arquitectura nueva, agregar sección **ADR breve dentro de este archivo**, con motivación, alternativas, riesgos y fecha.

## 8. ADR-002 — Alcance de historia y estrategia de sustitución (2026-11-10)

**Decisión explícita del propietario:** los datos históricos no justifican extender ni complicar esta mejora. Se descarta la migración de históricos operativos **del laboratorio** como condición de aceptación.

**Se conserva:** artículos/códigos/configuraciones que sigan vigentes o sean útiles; reglas, modalidades, unidades y permisos que el negocio requiera; esquema de seguridad; capacidad de venta y sincronización futura; exactitud del nuevo inventario desde su apertura.

**Se puede reiniciar en laboratorio, tras inventario y respaldo verificable:** ventas/voids de prueba, saldos y movimientos previos, compras y ajustes de prueba, consumos de personal/nómina de prueba relacionados, documentos y colas offline sintéticas; limpiar referencias **en orden de dependencia y solo en el entorno de pruebas**. Preferir recrear el laboratorio aislado con migraciones baseline y fixtures sintéticos, no una cadena de DELETE arbitrarios. El estado/alcance del reset debe ser auditable.

**No está autorizado por esta decisión:** borrar producción, datos reales, Tentrix, certificados, usuarios o cualquier otra aplicación. Antes de un eventual despliegue: identificar operaciones abiertas y pendientes offline y establecer corte o conciliación; «históricos no importan» **no equivale** a descartar ventas aún no sincronizadas. Si se necesita un cierre contable productivo, debe decidirse separadamente.

**Resultado arquitectónico:** elegir **migración limpia y corte coordinado**, no múltiples libros espejados con retrocompatibilidad permanente. La migración 088 actual sigue congelada porque propone copiar maestros por trigger.

## 9. Auditoría estática de impacto — esquema remoto, contratos y eliminación

**Evidencia examinada:** estructura y contenido de migraciones 001/005/009/010/011/016/017/019/020/021/022/024/028/029/040/041/047/048/049/050/051/052/053/054/055/056/059/060/063/065/072–081/084/085–087, además de tablas Drift, pull, repositorios administrativos y payloads de sincronización en `lib/`. El repositorio contiene 87 migraciones históricas y 088 propuesta/congelada. **Límite:** este es un censo de dependencias estático de código versionado, NO una consulta a `pg_catalog` ni a los registros físicos de Docker. F0 requiere obtener todas las FKs, triggers, funciones, grants, políticas y objetos existentes **desde la instancia** antes de ejecutar SQL. No dar por cerrada una dependencia que no fue vista en código.

### 9.1 Matriz de decisión por tablas maestras y configuración

| Tabla actual | Acción definitiva | Relación/impacto | Condición antes de ejecutar |
|---|---|---|---|
| `products` | **SUSTITUIR Y RETIRAR** como maestro, no mantener espejo | Hoy soporta venta/receta, modificadores, compra, stock, reportes, nómina y RPC POS. Cada consumidor deberá pasar a `items.id` | Inventariar todos los FKs y escritores; migrar artículos vigentes, luego cero lectores/escritores y sin FK restante |
| `packaging_items` | **SUSTITUIR Y RETIRAR** como maestro | Hoy lo referencian reglas, stock, movimientos, compras, API Admin y POS offline | Reglas/stock/ledger migrados; ninguna función utiliza `packaging_item_id` en tablas nuevas |
| `product_categories` | **CONSERVAR/RENOMBRAR** a `item_categories` | Categoría de cualquier artículo; padre/hijo, orden, tenant y activo | Relacionar por FK compuesta tenant+category; no mezclar categoría con tipo ni capacidad |
| `measurement_units` | **CONSERVAR Y REFORZAR** | Global o de restaurante; grupos count/mass/volume y factor base | Validación de grupo dimensional y tenant/global; impedir conversiones entre masa/volumen/unidad |
| `sales_types` | **CONSERVAR** | Modalidad de servicio comercial (dine_in, to_go, delivery), **no** tipo de artículo | default transaccional y RLS; continúa en venta y reglas |
| `product_packaging_rules` | **SUSTITUIR** por `item_consumption_rules` | `source_item_id` opcional según contexto, `consumed_item_id` FK a items, modalidad, alcance por pedido/por línea, cantidad/unidad | Diseñar idempotencia, prioridad de reglas, no aplicar doble consumo, tenant en todas referencias |
| `modifier_groups`, `modifier_options` | **CONSERVAR/EXTENDER** | Definiciones de opciones; valor que representa artículo debe referenciar `items.id`; opciones textuales siguen permitidas | No convertir texto libre en artículo falso; precios/stock snapshot de selección |
| `product_modifier_groups` | **RECONDUCIR/RENOMBRAR** `item_modifier_groups` | FK de producto padre → `items` | Mantener orden y permisos; quitar FK legacy |
| `product_recipes`, `product_recipe_lines` | **RECONDUCIR** a modelo de recetas por `items` (renombrar opcional tras corte) | Padre y componentes `item_id`, unidades, versión, merma, recursión y costo | Detectar ciclos, roles de componentes, protección de receta activa, atomicidad |
| `roles`, `permissions`, `role_permissions`, `profiles` | **CONSERVAR** | Introducir permiso propio `articulos.gestionar` si la matriz de permisos lo exige; inventario, precios y recetas con permisos separados | Migración explícita de rol; RLS y RPC no aceptan un rol por pantalla |
| `restaurants` | **CONSERVAR** | Raíz multitenant; todas FKs canónicas con `restaurant_id` | Comprobar FKs compuestas, índices, uniqueness y RLS |
| `pos_devices`, `settings`, `restaurant_tables`, `table_accounts` | **CONSERVAR** | Dispositivos, apertura de cuentas/mesas, configuración y operación POS | Ajustar solamente payload de catálogo y dependencias de producto |
| `payment_methods`, `expense_categories`, `operating_expenses` | **CONSERVAR** | No son maestros de artículos, aunque gastos/operación POS comparten RPC y transacción | Confirmar que gastos de materiales usen FK items cuando corresponda |
| `business_rules` | **CONSERVAR** | Reglas de negocio/empleados distintas de reglas de consumo de artículos | No fusionar conceptos |

### 9.2 Inventario, compras y ajuste (núcleo transaccional)

| Tabla/función | Decisión | Dependencia y reemplazo |
|---|---|---|
| `inventory_stock` + `packaging_stock` | **RETIRAR DESPUÉS DEL CORTE** | Un único saldo `item_stock` por restaurante, `item_id` y ubicación (si location existe/está habilitada). Saldo de apertura sintético; no sumar viejos ledgers más apertura |
| `inventory_movements` + `packaging_movements` | **RETIRAR DESPUÉS DEL CORTE** | Un solo `item_ledger_entries` con IDs de movimiento, `item_id`, origen, referencia, cantidad decimal, costo/moneda según política, terminal y clave idempotente. Los tipos de movimiento deberán abarcar compra, venta, consumo receta, empaque, personal, ajuste, anulación y reversión |
| `inventory_adjustment_number_settings` / `inventory_adjustment_documents` | **CONSERVAR** | Documento y numeración de ajuste; independencia de tipo de artículo |
| `inventory_adjustment_lines` | **EXTENDER/REEMPLAZAR FK** | `product_id` → `item_id` (y FK restaurante); conversiones de conteo verificadas |
| `apply_inventory_movement`, `apply_packaging_movement` | **SUSTITUIR** por `apply_item_movement` atómico | Validar saldos, costo, flags inventariables, deduplicación y autorización; no descontar `service`/non_inventory |
| `app_register_inventory_purchase_batch`, `app_register_packaging_purchase_batch` | **UNIFICAR** en compra de artículos, sobre ledger canónico | Costo compra, conversiones, stock, idempotencia; no dos rutas de escritura |
| `app_register_inventory_adjustment_batch` | **ACTUALIZAR** | Nuevo tipo de documento mantiene número y líneas referidas a items; prueba de stock negativo y concurrencia |
| Informes de inventario y costo | **ACTUALIZAR** | Leer `item_stock` + `item_ledger_entries`; no sumar dos libros de origen |

**Decisión de granularidad:** no mantener `packaging_stock` separado porque el empaque ya es `items`. `quantity_delta` decimal coherente con unidades y recetas; no degradar ingrediente a entero porque el empaque antes fuera entero. Idempotencia con constraint de origen/operación, movimientos reversibles por referencia a movimiento original y controles de tenant.

### 9.3 Recetas, personal, nómina, reportes y snapshots

| Contrato | Tablas/funciones detectadas | Cambio requerido |
|---|---|---|
| Recetas | `product_recipes`, `product_recipe_lines`, `app_save_product_recipe`, `app_recipe_component_expands_to`, `app_recipe_unit_cost`, `pos_apply_recipe_inventory_movements`, `pos_reverse_recipe_inventory_movements` | Sustituir todas las referencias padre/componente a `items`; conservar semántica de versión, merma, cálculo de costo y reversión mediante movimientos originales |
| Personal y nómina | `employee_raw_material_consumptions`, `employee_raw_material_consumption_lines`, `payroll_runs`, `payroll_run_lines`, `payroll_payment_receipts`; `app_save_raw_material_staff_consumption`, `app_post_payroll_employee`, `app_reverse_payroll_payment_receipt`, `app_raw_material_stock_quantity`, `app_get_raw_material_product_options` | **NO ELIMINAR** nómina/empleados; convertir línea de material a `item_id`, filtrar por capacidad de materia prima, registrar consumo en nuevo ledger. Revisar resultados payroll antes de actualizar |
| Venta | `sales`, `sale_items`, `sale_voids`, `cash_register_sessions`, `table_accounts` | **CONSERVAR** tablas de cabecera y cierre; `sale_items.product_id` → `item_id`; snapshots de nombre/precio/costo, modalidad y opciones son obligaciones del contrato futuro aunque se descarten datos previos |
| Reportería | `app_get_product_performance_report`, `app_get_daily_sales_report`, `app_current_sale_item_unit_cost`, `pos_update_sale_recipe_costs`, reportes de inventario negativo/valorización | Reescribir joins y grupos por `item_id` y snapshot de venta; no depender de `products` ni `packaging_items` tras corte |
| Modificadores | `modifier_groups`, `modifier_options`, `product_modifier_groups`, `sale_items.selected_options_label` | Referencias de artículo a `items`, mantener opciones sin artículo cuando sean instrucciones; no confundir receta con modificación comercial |
| Cocina | Salida basada en ventas y selección POS | Mantener snapshot de instrucciones y línea; no recalcular contra receta vigente después del cobro/anulación |
| Operación general | `employees`, `business_rules`, `staff_consumption_number_settings`, `invoice_number_settings` y otras tablas numeradoras | **CONSERVAR**; solo tocar las referencias materiales a artículos |

**Principio de poda:** descartar transacciones históricas de prueba en laboratorio NO autoriza borrar la **estructura** de nómina, ventas, mesas o informes. Se retiran **solo** tablas maestras/ledgers redundantes cuando no queden consumidores. Históricos prescindibles evitan migrar filas antiguas; no eliminan la necesidad de migrar el código.

### 9.4 App local Drift y sincronización POS (bloqueante de corte)

**Drift schema version observada:** `34` en `lib/core/database/app_database.dart`.

| Objetos Drift existentes | Decisión futura | Punto de impacto |
|---|---|---|
| `LocalProducts`, `LocalPackagingItems` | **SUSTITUIR** por `LocalItems` | POS/Backoffice local, pull, filtros, código comercial, flags y unidades |
| `LocalInventoryStock`, `LocalPackagingStock` | **SUSTITUIR** por `LocalItemStock` | Checkout offline, lectura de stock y disponibilidad |
| `LocalInventoryMovements`, `LocalPackagingMovements` | **SUSTITUIR** por `LocalItemLedgerEntries` | Compra, receta, empaques, reversión, delta pendiente de sync |
| `LocalProductPackagingRules` | **SUSTITUIR** por `LocalItemConsumptionRules` | Resolver consumo por modalidad y artículo/pedido |
| `LocalSales`, `LocalSaleItems`, `LocalSaleVoids` | **CONSERVAR/ADAPTAR** | Snapshot transaccional con `item_id`; no romper apertura/cierre de caja |
| `LocalSyncQueue`, `LocalSyncSettings` | **CONSERVAR/EVOLUCIONAR FORMATO** | Enviar nuevos payloads, idempotencia, retries, bloqueo por versión |
| `LocalSalesTypes`, `LocalProductCategories` | **CONSERVAR/RECONDUCIR** | Modalidad vigente y categorías de item |

**Contratos explícitos que deben cambiar simultáneamente o por versión:** `pos_pull_operational_catalog`, `pos_sync_sale`, `pos_sync_staff_consumption`, `pos_sale_payload_for_current_stock_rules`, `pos_record_nontracked_packaging_movements`; `supabase_catalog_pull_service_catalog_part.dart`, `...inventory_part.dart`, `...missing_part.dart`, `supabase_sync_remote_sender_payloads_part.dart`, repositorios admin `...catalog_part.dart` y `...packaging_part.dart`, servicios de inventario y Drift migraciones.

**Riesgos ocultos comprobados en código:** `_markMissingProductsInactive` y `_markMissingPackagingItemsInactive` son procedimientos separados: un pull parcial/filtrado puede inactivar un artículo que solo esté fuera del filtro. El nuevo pull debe ser **catálogo íntegro del restaurante** con permisos de visibilidad POS por separado. Además `pos_sync_sale` ha sido **redefinido en varias migraciones** (019/028/029/051/052/053/054/065): jamás modificar una versión antigua y asumir que es la que se ejecuta hoy; leer su definición real desde `pg_proc` antes de diseñar el reemplazo.

**Regla de corte:** con historia de laboratorio descartable, no se necesita conversor permanente de bases SQLite viejas de terminales de prueba; se puede reinstalar/recrear Drift limpio al nuevo schema. Antes de ello: comprobar y cerrar todas las colas pendientes y tickets abiertos que tengan valor. En producción, ningún terminal antiguo debe enviar el payload anterior hacia el endpoint nuevo sin contrato explícito de versión o actualización coordinada.

### 9.5 Modelo relacional mínimo recomendado (solo definición; DDL aún no aprobado)

| Objeto objetivo | Crear / adaptar | Relaciones/constraints esenciales |
|---|---|---|
| `items` | **CREAR AUTORITATIVO** | PK UUID, FK restaurante, UNIQUE tenant+code, nombre, `item_type` (inventory/non_inventory/service), precio/costo, flags de compra/venta, estado; identidad inmutable |
| `item_classifications` + `item_classification_links` | **CREAR si clasificación N:M necesaria** | PK clasificación por restaurante y FK compuesta a items; un artículo puede cumplir múltiples roles; categoría jerárquica sigue aparte |
| `item_units` | **CREAR** | FK `items`/measurement_units, base/compra/venta, factores positivos, una base y unidad válida por función |
| `item_stock` | **CREAR** | UNIQUE (restaurant, item, ubicación), FK item, control tipo Inventory, saldo materializado solo por RPC ledger |
| `item_ledger_entries` | **CREAR** | FK item/ubicación, qty decimal, movimiento y referencia original/idempotencia, costo, timestamp, actor/terminal; append-only y reversión explícita |
| `item_consumption_rules` | **CREAR** | FK `consumed_item_id`; contextos producto/modalidad/pedido; qty/unit; evitar colisiones de precedencia y doble descuento |
| `item_prices` | **DIFERIR HASTA REGLAS DE PRECIOS** | Precio base en items suficiente para fase inicial; crear tabla de listas/vigencias solo si se requiere, no por imitación BC |
| `item_inventory_policies` | **DIFERIR/INCORPORAR EN ITEMS** | Costeo y stock negativo tras decidir política explícita; no crear tabla sin casos reales |
| `item_categories` | **RENOMBRAR/ADAPTAR** `product_categories` | FK compuesta y jerarquía; roles múltiples separados |
| `item_recipe_* ` | **RENOMBRAR/ADAPTAR** tablas de receta existentes | FKs padre y componente a item; no introducir una segunda receta |
| `item_modifier_groups` | **RENOMBRAR/ADAPTAR** relación product-modifier | FK item y conservación de agrupación/opciones |
| `sale_items.item_id`, `inventory_adjustment_lines.item_id`, `employee_raw_material_consumption_lines.item_id` | **CAMBIAR FK** | Ninguna referencia a productos maestro legacy tras corte |

**FK multiempresa:** preferir `UNIQUE(restaurant_id,id)` + FK compuesta `(restaurant_id,item_id)` para evitar referencias cross-tenant incluso desde SECURITY DEFINER. `measurement_units` globales/nacionales requieren validación de scope y grupo dimensional.

### 9.6 Orden seguro de reemplazo y eliminación

1. **F0 — Inventario efectivo SQL:** capturar `pg_class/pg_attribute/pg_constraint/pg_depend/pg_proc/pg_trigger/pg_policies/pg_indexes`, grants, FKs dinámicas y tablas no descubiertas en migraciones. Resolver con evidencia los casos de referencias desde nómina, ventas/reportes, cocina y stock. Consultar estado de 088 **sin asumirlo**.
2. **Laboratorio:** respaldo del estado actual y conjunto sintético reproducible. Distinguir configuraciones vigentes a portar de operaciones históricas descartables. Si se aprueba el corte limpio, recrear solo el laboratorio aislado, con migraciones baselined que reflejen core final; **no ejecutar reset ahora durante la auditoría**.
3. **Modelo canónico:** crear items, clases/capacidades necesarias, unidades y constraints. Registrar fuentes de datos de artículos vigentes con códigos consistentes. Sin maestros legacy recibiendo escrituras nuevas.
4. **Relaciones y motor:** convertir recetas, reglas, modificadores, compras/ajustes, ventas, personal/nómina e informes; RPC de movimientos y catálogo; probar FIFO/consumo/void/idempotencia y costos contra fixtures **nuevos**.
5. **POS offline:** sustituir tablas Drift y payloads/pull por catálogo y ledger únicos, versionar API, eliminar desactivación incorrecta por pull filtrado. Usar terminales de prueba nuevas/limpias para el corte local.
6. **Retiro controlado:** consultar `pg_depend` + búsquedas en código; **no borrar tablas** mientras tengan FKs, funciones, triggers o escritores. Eliminar `products`, `packaging_items`, `inventory_stock`, `packaging_stock`, `inventory_movements`, `packaging_movements`, `product_packaging_rules` solo cuando todas las dependencias hayan sido sustituidas y probado el esquema final. No borrar `sales`, nómina ni configuración.
7. **Pruebas y gates:** esquema limpio + inserts/updates; roles admin/productos/inventario/otro tenant; control non_inventory/service, unidades/decimales, stock concurrencia, sale/void, pedido/ítem, receta, gastos/consumo personal, sync offline y reenvío. Solo entonces cerrar F1/F2 y habilitar F3 pantallas.

### 9.7 Riesgos de última hora convertidos en decisiones anticipadas

| Riesgo | Decisión preventiva |
|---|---|
| Datos históricos sin valor | No migrar históricos; **sí** probar desde cero el futuro ledger y snapshots. No construir adaptadores eternos |
| Precio de servicio y producto no inventariado | Permitidos como artículos; **no** generan stock. Venta guarda snapshot, no exige existencia física |
| Artículo inventariable pero no vendible | Se puede comprar y consumir; `is_sellable` independiente de clasificación |
| Artículo con dos usos (vendido y empaque) | N:M clasificación/capacidades, una sola PK; no copiar producto |
| Empaque por pedido y por línea | Dos contextos explícitos, no dos descuentos implícitos; precedencia y deduplicación |
| Unidades y factores | Validar dimensiones, factor base y costo base; no interpretar nombres como equivalencia |
| Anulación tras modificar receta o regla | Reversar ledger original, jamás usar regla vigente |
| Operaciones de personal/nómina | Se conserva estructura; líneas de consumo ahora referencian `items`; pruebas de payroll |
| Pérdida de conexión/terminal vieja | Cola versionada, idempotencia y plan de corte antes de limpieza |
| Default de modalidad | RPC transaccional para cambiarlo; no parte de tipo técnico de artículo |
| RLS y bypass RPC | Matriz completa con JWT; FK compuesto tenant y guardas `SECURITY DEFINER` |
| Informe basado en `product_name` | Usar `item_id` y snapshots transaccionales; evitar lookup vivo para pasado |
| Variación de costo/precio | Definir redondeo, monedas, snapshots y política de costo antes del motor definitivo |
| `flutter analyze` bloqueado | Mantener bloqueo declarado; SQL y pruebas app se reportan por separado, no aceptar build como análisis global |

### 9.8 Estado verificable de la auditoría

- **Comprobado en repositorio:** dualidad de maestros, dos ledgers/stock, FKs de ventas/recetas/ajustes/consumo de personal, RPC de compra/POS/receta, Drift v34, dos pulls e inactivaciones, permisos RLS y triggers 085–087.
- **No comprobado aún contra Docker:** tablas adicionales que el entorno tenga, cuerpo **final** de funciones redefinidas, triggers vivos, volúmenes y cifras de filas, rutas efectivas de grants, cambios manuales fuera de migraciones, operación multi-terminal real, estado de 088.
- **G0:** permanece **ABIERTO** hasta auditoría SQL de `pg_catalog` y diagnóstico de las discrepancias; ninguna decisión de DROP/productivo se ejecutará de manera anticipada. El script versionado `supabase/tests/item_master_preflight_readonly.sql` es el censo reproducible. **Sus resultados no se han ejecutado ni certificado desde GitHub**.


### 9.9 Cierre F0 contra PostgreSQL local del laboratorio Kivo (2026-11-10)

Se ejecutó `supabase/tests/item_master_preflight_readonly.sql` exclusivamente
contra el contenedor local `supabase_db_smoo_control`, dentro de una transacción
`BEGIN READ ONLY`/`COMMIT`. No se ejecutaron migraciones, DDL, reset, `DROP`,
`DELETE`, `TRUNCATE` ni cambios de datos. El script terminó sin error
reproducible y no requirió corrección.

Resultados numéricos:

- 55 relaciones públicas y 566 columnas públicas; 232 columnas fueron devueltas
  por el filtro de entidades/campos de impacto.
- 143 FKs validadas; 12 referencias directas hacia `products`/`packaging_items`
  en stock, movimientos, reglas, recetas, modificadores, ventas, ajustes y
  consumo de personal.
- 155 restricciones de PK/UNIQUE/CHECK/EXCLUDE; 114 índices públicos, 12 de
  ellos propios de los siete objetos legacy auditados.
- 65 políticas RLS, 6 triggers no internos y 70 funciones/RPC relacionadas.
- 1.155 grants: 385 para `anon`, 385 para `authenticated` y 385 para
  `service_role`. RLS reduce el acceso efectivo en varias tablas, pero el grant
  amplio no satisface todavía el contrato de mínimo privilegio.
- Datos: `products` 2, `packaging_items` 3, `inventory_stock` 2,
  `inventory_movements` 2, `packaging_stock` 1, `packaging_movements` 7 y
  `product_packaging_rules` 4.
- Los ocho checks de colisión, códigos, tenant y referencias cruzadas dieron
  `0` bloqueantes.
- `pg_depend` reportó 165 dependencias para los siete objetos legacy: 53
  restricciones, 13 políticas, 4 triggers, 32 defaults/atributos y
  dependencias de tipo/relación.

**Migración 088:** NO está aplicada. El ledger local contiene exactamente
001–087; no existe fila 088 ni migración `item_master`, y no existen
`public.items`, `public.item_stock` ni `public.item_ledger_entries`.

#### Matriz definitiva de impacto

| Dominio | Impacto real confirmado | Decisión F1/F2 | Bloqueante |
|---|---|---|---|
| Productos y empaques | Dos maestros físicos, 5 filas y 12 FKs directas; no existe `items` | Crear `items` autoritativo y adaptar catálogos | Sí: consumidores y escritores legacy activos |
| Inventario | Dos stocks y dos ledgers, 12 filas; RPC separadas para cada uno | Crear `item_stock` + `item_ledger_entries` y unificar costo, unidades e idempotencia | Sí: no existe libro canónico |
| Ventas y cocina | `sale_items.product_id`, ventas/voids y RPC POS/receta usan producto | Cambiar a `item_id`, conservando snapshots y reversión original | Sí: contratos actuales activos |
| Recetas y modificadores | Recetas, líneas y `product_modifier_groups` referencian `products` | Adaptar padre/componente/opción a `items` | Sí: FKs y RPC activas |
| Nómina/personal | Líneas de consumo referencian `product_id`; la nómina debe conservarse | Cambiar la referencia material a `item_id` y conectar al ledger | Sí: consumo y payroll vigentes |
| Sincronización/POS Drift | Drift v34, pulls separados y múltiples `pos_sync_*` vigentes | Versionar payload/pull y sustituir tablas locales por items/stock/ledger únicos | Sí: terminal viejo y pull parcial |
| Seguridad | RLS presente, grants amplios y 70 `SECURITY DEFINER` relacionados | Revisar mínimo privilegio, tenant compuesto, JWT y guardas RPC | Sí para G1 |

**Crear en F1, tras diseño y pruebas:** `items`, `item_units`, `item_stock`,
`item_ledger_entries` y `item_consumption_rules`; `item_classifications` y sus
enlaces solo si se confirma la necesidad N:M. Precios e inventario-policy quedan
diferidos hasta ratificar sus reglas.

**Modificar/reconducir:** `product_categories`, `sale_items`,
`inventory_adjustment_lines`, `employee_raw_material_consumption_lines`,
`product_recipes`, `product_recipe_lines`, `product_modifier_groups`,
`product_packaging_rules`, sus RPC/reportes y los contratos de pull/sync POS.
`sales`, `sale_voids`, nómina, empleados, mesas, dispositivos, numeradores y
configuración se conservan; solo se adaptan referencias materiales.

**Retirar después del corte, migración, pruebas y cero dependencias:**
`products`, `packaging_items`, `inventory_stock`, `packaging_stock`,
`inventory_movements`, `packaging_movements` y `product_packaging_rules`.
Ninguna tabla se eliminó en F0.

**Gate G0: APROBADO PARA DISEÑO DE F1, NO PARA MIGRACIÓN.** F0 se cerró con auditoría ejecutada contra PostgreSQL local, 8 verificaciones sin bloqueantes de integridad y censo real de dependencias. La ausencia de `items`, la migración 088 no aplicada, 12 FKs legacy y 165 dependencias **son el alcance de sustitución de F1/F2**, no fallas del censo G0. Los grants amplios y las RPC requieren plan de mínimo privilegio y pruebas de seguridad durante F1/F2. **Autorizado:** diseñar DDL definitivo, orden de dependencias, contratos, pruebas y reversión. **No autorizado:** aplicar la 088 congelada, ejecutar migraciones, eliminar tablas, alterar POS/pantallas ni tocar producción antes de validar y aprobar el diseño de F1.

## 10. Diseño técnico F1 — contrato de base de datos para implementación

**Fecha de diseño:** 2026-11-10. **Estado:** diseño especificado para revisión técnica; **ningún SQL ejecutado ni migración autorizada**. Este diseño reemplaza la 088 en borrador; **no se reutiliza su esquema de maestro espejo**. Las 87 migraciones históricas siguen como referencia del esquema actualmente desplegado.

### 10.1 Límites de la fase y decisiones cerradas

- **F1 contiene**: una autoridad de artículos `items`; identidades/códigos, tipos y capacidades, categorías/unidades; permisos/RLS; reglas de integridad y contrato de escritura; backfill limitado a *maestros vigentes* de laboratorio; estructura del inventario canónico, pero **sin habilitar dos motores que escriban saldos**.
- **F2 contiene**: migración funcional de los consumidores: reglas de empaque, recetas, modificaciones, compras/ajustes, ventas/void, consumo de personal/nómina, reportes, RPC de catálogo/POS, motores de inventario, Drift y sync. Si F1 requiere crear una tabla con FK `items` antes de convertir esos consumidores, quedará **sin autoridad de transacciones** hasta F2. **No eliminar legacy antes de F2 validada.**
- **Autoridad única sin contradicción**: al habilitar el corte, solo el servicio/RPC de `items` podrá crear/modificar datos maestros; `products` y `packaging_items` permanecen exclusivamente como estructuras antiguas de compatibilidad *sin nuevos writes operativos*. Si todavía existe un cliente que escribe esas tablas, el corte **NO puede habilitarse**. No crear triggers de réplica bidireccional ni un espejo permanente.
- **Laboratorio**: los históricos de prueba son descartables, pero los productos, empaques, categorías, unidades y reglas útiles deben mapearse para iniciar. Ningún reset debe alcanzarse por una ejecución automática de F1. Producción y `main` excluidos.

### 10.2 Especificación de `items`

| Columna / restricción | Diseño | Justificación |
|---|---|---|
| `id uuid primary key default gen_random_uuid()` | Inmutable | Identidad técnica única |
| `restaurant_id uuid not null` | FK `restaurants`, `UNIQUE(restaurant_id,id)` | Aislamiento y FKs tenant-compuestas |
| `code text not null` | `UNIQUE(restaurant_id, lower(btrim(code)))`; no vacío; control de longitud en contrato | Código comercial, no UUID obligatorio |
| `name text not null` | no vacío; `search_name` derivado o índice para búsqueda, no segunda fuente | Nombre canónico |
| `item_type text not null` | `inventory | non_inventory | service` | Política física de stock/costo |
| `category_id uuid null` | FK compuesta tenant; jerarquía `item_categories` | Clasificación principal, distinta del tipo |
| `is_active, can_sell, can_purchase, visible_in_pos, uses_recipe` | booleanos explícitos | Capacidades combinables; visibilidad POS no implica vendible |
| `cost numeric(18,6), price numeric(18,4)` | no negativos, moneda/snapshot definidos en transacciones; evitar la confusión actual entre costo de compra y costo base | Semántica de valor estable |
| `base_unit_id uuid not null` | unidad válida para tipo/tenant; inmóvil tras movimientos incompatibles | Cantidades normalizadas |
| `created_at, updated_at` | timestamps auditables | Mantenimiento |

**Reglas de negocio ejecutables:** `item_type=service` o `non_inventory` nunca permite stock físico ni asientos en el ledger; un producto elaborado puede venderse con `uses_recipe` y consumir ingredientes sin tener saldo de producto terminado; empaque es **capacidad/clasificación**, no un tipo técnico excluyente. `can_sell=false` impide agregar líneas de venta nuevas, pero no invalida una venta ya contabilizada. Desactivar en vez de borrar maestros usados.

**Clasificación comercial**: las necesidades actuales `sale_product / raw_material / packaging` no son mutuamente excluyentes. Se elige **N:M explícita**: `item_classifications(id,restaurant_id,code,name,is_active)` e `item_classification_links(restaurant_id,item_id,classification_id)`, con FK compuesta e índices y valores iniciales de tipos de uso reales. `item_categories` sigue como jerarquía para navegación; una categoría no sustituye la clasificación funcional. Validar permisos de edición separados de la clasificación para no hacer de una etiqueta una autorización.

### 10.3 Unidades, costo y conversiones

Reusar `measurement_units` como catálogo de unidades global/tenant. Crear `item_units(restaurant_id,item_id,unit_id,quantity_in_base numeric(18,8), is_base, is_purchase, is_sale, is_active)`. PK/UNIQUE por restaurante+artículo+unidad; exactamente una unidad base por artículo (aplicar mediante RPC transaccional con validación diferida o atributo base en items y constraint); los roles venta/compra deben tener definición inequívoca; prevenir conversiones entre grupos `count/mass/volume`.

`quantity_in_base` indica cuántas unidades base son **una** unidad del renglón. Ej.: caja 12 unidades => factor 12. El saldo y la receta trabajan en unidad base. `cost` del maestro es costo **por unidad base**, nunca precio de una caja; precio de venta también tiene una unidad explícita. Una compra en caja calcula cantidad/costo base, y la venta guarda snapshot de unidad, factor y precio. No reutilizar sin conversión el valor actual `products.cost`: la migración 063 lo documenta como costo por unidad de compra para materia prima.

### 10.4 Inventario canónico (estructura F1, operaciones F2)

| Objeto | Campos y restricciones mínimos |
|---|---|
| `item_stock` | `restaurant_id`, `item_id`, `location_id` (solo si se incorpora ubicación operativa; de lo contrario identificador de ubicación única definido explícitamente), `quantity_on_hand numeric(18,6)`, `version`, `updated_at`; UNIQUE tenant+item+ubicación |
| `item_ledger_entries` | `id` identificador de movimiento, `restaurant_id`, `item_id`, ubicación, `movement_type`, `quantity_delta numeric(18,6)`, `unit_cost_base numeric(18,6)`, `source_type`, `source_id`, `operation_key`, `reversal_of_id`, `device_id`, `actor_id`, `occurred_at`, `recorded_at`; constraints FK tenant y UNIQUE por `operation_key` de la operación de negocio |
| RPC `apply_item_movement` | Autoridad única sobre ledger y saldo, bajo transacción con lock de stock, chequeo de tipo, permisos/contexto de origen, idempotencia por operación, control de negativo y costo; el cliente NO puede INSERT/UPDATE/DELETE directamente en stock/ledger |

**Política de movimiento:** append-only; reversión con nuevo movimiento cuya `reversal_of_id` referencia el original, cantidad opuesta y costo original; máximo una reversión efectiva por movimiento (salvo política explícita de reversión parcial); discrepancia de reintento con misma clave y diferente payload => conflicto, nunca éxito falso. Usar criterio único de saldo `SUM(quantity_delta)`, con `item_stock` como proyección aceleradora. Apertura de inventario = asientos iniciales por artículo/ubicación y **no** reimportar movimientos viejos; no exigir saldos históricos del laboratorio.

**Ubicaciones:** Kivo hoy opera stock por restaurante. **No crear un módulo multi-almacén inventado**: en la primera implementación mantener ubicación lógica única por restaurante; diseñar `location_id` opcional solo con FK real a un catálogo de ubicaciones si existe y se decide activarlo. Nunca usar cadenas libres ambiguas como ubicación en claves.

### 10.5 Consumo, recetas y exposición POS

- `item_consumption_rules` sustituye `product_packaging_rules` después de F2, con `restaurant_id`, `source_item_id` nullable, `consumed_item_id` obligatorio, `sales_type_id` nullable, `scope` = `per_sale_line | per_order`, `quantity`, `unit_id`, `priority`, `is_active`. Una regla per-order se calcula **una vez por pedido**, no por línea; una per-line multiplica cantidad. Definir regla de prioridad ante varias coincidencias antes de activar (no sumar accidentalmente reglas globales y específicas). Se mantiene `sales_types` y el default de modalidad se cambia por RPC atómica.
- `product_recipes` / `product_recipe_lines` conservan sus modelos útiles de versión, merma y unidades; se cambian FK de `product_id` / `component_product_id` a referencias `items`. Una receta tiene padre y N componentes; rechazar ciclos, componentes inactivos, unidades incompatibles y cambios destructivos después de consumos.
- `modifier_groups/options` se conservan: una opción puede ser una instrucción textual o una referencia a artículo. Extras/sustituciones/exclusiones deben producir efectos explícitos sobre precio, inventario y mensaje de cocina, no alterar en silencio la receta maestra.
- La exposición en POS es una capacidad/política distinta: el catálogo completo pertenece al restaurante; el terminal recibe *catálogo completo versionado* y una configuración separada de visibilidad. **No convertir artículo no visible en «faltante/inactivo»** durante un pull parcial.
- `sale_items` tendrá FK `item_id` y snapshots de nombre, código, unidad, cantidad, precio, costo, modificadores/impuestos aplicables. La historia descartable del laboratorio **no** elimina la necesidad de snapshots en ventas nuevas.

### 10.6 Seguridad y contratos de escritura

- `items`, clasificaciones, unidades, reglas, stock y ledger: RLS `restaurant_id = current_restaurant_id()`, más FK compuestas para evitar relaciones cross-tenant aunque una RPC sea SECURITY DEFINER. Las unidades globales tienen validación particular de scope.
- Matriz de permisos: `articulos.ver` / `articulos.gestionar`, `inventario.gestionar`, `recetas.gestionar`, `tipos_venta.gestionar` y `reglas_consumo.gestionar` donde sean necesarios. Mapear derechos `productos.gestionar` / `empaques.gestionar` de forma explícita, sin promoverlos automáticamente a administrador general.
- Escritura del maestro solamente vía RPC `app_upsert_item` con actor/tenant/permiso, código normalizado, restricciones de tipo y validaciones; **denegar DML directo a roles cliente**. RPCs `SECURITY DEFINER` con `SET search_path = public, pg_temp`, grants de `EXECUTE` mínimos, sin permitir ejecución anónima ni elevación `service_role` desde el cliente. Registrar auditoría de cambios.
- `item_stock` y `item_ledger_entries`: consultas acotadas al restaurante; escritura exclusivamente mediante `apply_item_movement` y contexto POS confiable/dispositivo habilitado. Crear pruebas para admin, solo artículos, solo inventario, POS, sin permisos, tenant externo y reintentos falsificados.
- **Observación G0:** 1.155 grants reportados, 385 por rol `anon/authenticated/service_role`; una concesión de tabla no prueba lectura efectiva si RLS la niega, pero se requiere auditoría de grants, POLICY y definer antes de pasar G1.

### 10.7 Secuencia SQL definitiva, sin ejecución aún

**Secuencia recomendada para el laboratorio con corte limpio:**

1. Registrar versión y huellas del schema (87 aplicadas, 088 ausente), exportar respaldo **local** de configuraciones, dos productos/tres empaques y datos indispensables; comprobar ausencia de operaciones pendientes de interés.
2. Preparar una migración **nueva** posterior al conjunto aplicado (número 088 solo tras retirar/sustituir el borrador 088 no aplicado **en rama**, con acta, o 089 con nombre nuevo si el archivo 088 ya fue observado/aplicado fuera del laboratorio). No editar 001–087.
3. Crear `items`, categorías/clasificaciones, unidades y restricciones seguras; portar maestros útiles conservando UUID cuando no colisionan; resolver código comercial de empaques (no tenían `code`) mediante numerador/serie **legible**, no `PKG-<UUID>` impuesto como código visible.
4. Crear tablas canónicas de inventario y reglas, **sin** conectar simultáneamente el motor antiguo. Preparar contratos RPC y políticas con denominación única.
5. Convertir FKs de recetas, modificadores, ventas, ajustes, consumos de personal y reglas para apuntar a `items`. Con historia descartable se pueden vaciar **solo transacciones de laboratorio** en un entorno aislado reproducible; no borrar usuarios, roles, permisos, configuraciones ni datos de otras aplicaciones.
6. Actualizar todas las funciones finales de catálogo, compras, inventario, receta, POS, reportes y nómina; verificar el cuerpo efectivo de `pos_sync_sale` (múltiples redefiniciones). Retirar puntos de escritura legacy antes de activar el endpoint canónico.
7. Actualizar en corte coordinado Drift v34 → nueva versión con `LocalItems/LocalItemStock/LocalItemLedgerEntries/LocalItemConsumptionRules`, payloads versionados, pull íntegro y reconexión de terminales de prueba. Ningún POS viejo puede continuar escribiendo el contrato anterior sin adaptador temporal probado.
8. Una vez sin FK, trigger, view, policy, RPC, task o cliente que dependa de cada tabla vieja, retirar en orden de `pg_depend` `product_packaging_rules`, `inventory_stock`, `packaging_stock`, `inventory_movements`, `packaging_movements`, `packaging_items`, `products`. **Prohibido `DROP ... CASCADE`** como sustituto de inventario de dependencias.
9. Sembrar fixtures de venta/receta/empaque/servicio y asientos de apertura; probar y cerrar G1/G2; únicamente entonces iniciar interfaz F3.

**Nota de coordinación de fases:** la autoridad completa sobre stock y operaciones no existe hasta F2. Por ello la activación de `app_upsert_item` o el retiro de escrituras legacy debe ocurrir como **corte coordinado de F1+F2**, no con el Backoffice/POS antiguos ejecutándose. Un F1 «estructural» puede validarse en schema de laboratorio sin entrar en operación hasta completar F2.

### 10.8 Especificación de pruebas antes de autorizar DDL

| Suite | Aserciones obligatorias |
|---|---|
| Migración de catálogo | 2 productos/3 empaques vigentes mapeados o sustituidos deliberadamente; UUID sin colisión, categorías y códigos normalizados; cero huérfanos |
| Tipos | inventario con stock, servicio sin ledger, no inventariado sin saldo; rechazar cambio de tipo con transacción incompatible |
| Seguridad | tenant externo sin lectura/escritura, anon denegado, permisos parciales, RPC SECURITY DEFINER sin bypass |
| Unidades | caja→unidad, kg→g, redondeo, dimensión incompatible, costo de materia prima por unidad de compra → costo base |
| Inventario | compra, ajuste, receta, empaque, venta, movimiento simultáneo, stock insuficiente, duplicado idempotente, operación misma clave distinto payload |
| Reglas | consumo `per_order` vs `per_sale_line`, modalidad `delivery/pickup/to_go/dine_in`, regla inactiva, superposición y prioridad |
| Ventas/void | venta con receta, extras y empaque; anulación 1 vez revierte movimientos originales y costo snapshot; cambios posteriores en reglas no alteran la reversión |
| Personal/nómina | descuento de materia prima, registro en ledger, nómina y reversión sin escritura en tabla legacy |
| Sync/Drift | terminal v34 bloqueada o migrada expresamente; tickets/colas pendientes revisados; pull parcial no inactiva artículos legítimos, reintento offline sin doble descuento |
| Dependencias | cero FK/RPC/trigger/view/app write contra maestros/ledgers legacy antes de DROP; compilación y suites completas sin excepciones ocultas |

**Go/No-go para ejecutar F1:** DDL generado en una rama de implementación nueva y revisado contra este contrato, backup del laboratorio disponible, plan de reversión seguro, análisis de permisos y orden exacto de corte. **G1 no se aprueba por tener tablas creadas; debe demostrar autoridad única y pruebas.**

### 10.9 Decisiones explícitamente diferidas (no son bloqueos para diseñar core)

### 10.10 Revisión DDL F1 — materialización documental del diseño (2026-11-10)

**Artefacto:** `supabase/design/ITEM_CORE_F1_DDL_DRAFT.sql`, intencionalmente **fuera de `supabase/migrations`**, marcado NO EJECUTAR y terminado en `ROLLBACK`. Es una especificación estructural para inspección, **no una migración aprobada, aplicada ni certificada por PostgreSQL**. La migración 088 espejo permanece congelada.

**Objetos incluidos en el borrador:** `items`, `item_classifications`, `item_classification_links`, `item_units`, `item_stock`, `item_ledger_entries`, `item_consumption_rules`; restricciones compuestas de restaurante, índices, RLS de lectura y revocación de escrituras directas en nuevas tablas. Conserva `measurement_units`, `product_categories` y `sales_types` como entidades existentes durante el diseño. No añade triggers de espejo, no altera `products`/`packaging_items`, no mueve filas y no elimina nada.

**Decisiones de integridad comprobadas mediante revisión de DDL (todavía sin ejecutar):**

1. `product_categories(restaurant_id,id)` y `sales_types(restaurant_id,id)` reciben UNIQUE compuestos **antes** de ser objetivos de FK. La regla referenciada por modalidad de servicio usa FK compuesta para prohibir cross-tenant.
2. Las clasificaciones admiten N:M; no se asume una única clase de negocio. La categoría principal puede ser nullable.
3. `base_unit_id` es una unidad del catálogo global/tenant existente; `item_units.quantity_in_base` determina conversión. Las invariantes «exactamente una unidad base efectiva, misma dimensión, unidad activa» **no se garantizan solo con las constraints actuales**: son requisitos de RPC y triggers/constraints adicionales antes de aprobar G1.
4. `item_ledger_entries` lleva `operation_key`, `request_digest`, fuente, cantidad y referencia de reversión compuesta tenant+item; estas columnas no sustituyen una función transaccional de validación idempotente. **No activar ventas ni compras sobre estas tablas** sin la RPC `apply_item_movement`.
5. `item_stock` es materialización, no fuente de verdad. Su cambio exige serialización/locks y exactamente un ledger, no DML de cliente.
6. Actualmente no se creó `locations`; stock se mantiene por restaurante+item, evitando inventar almacenes. La expansión a ubicaciones exige una migración futura con nueva clave.
7. **Gap pendiente F1/F2**: el borrador no incluye implementación de `app_upsert_item`, `apply_item_movement`, `item_consumption_rules` resolver, reglas de unidades/tenant global, ledger `append-only`, permisos efectivos por RPC, semillas/backfill ni corte Drift. Todos son requisitos de implementación; no se consideran satisfechos por la existencia del archivo.
8. **Gap de validación:** la especificación no ha sido ejecutada en PostgreSQL/CI ni sometida a pruebas JWT/RLS. G1 continúa bloqueado. Ejecutar una prueba de parseo y transacción rollback exclusivamente en una **base clonada y desechable**, nunca en el laboratorio vivo o producción, y corregir cualquier divergencia sin alterar registros.

**Aprobación de diseño ≠ autorización de migración:** para convertir el borrador en migración, primero completar invariantes y RPCs, pruebas automáticas de esquema/RLS, mapa de dependencias F2, política de costo base/negativos y corte local controlado. El SHA del borrador y resultados de pruebas deberán registrarse aquí.



- Listas de precios avanzadas, promociones, múltiples almacenes y lotes/caducidad: no crear tablas por anticipación; diseñar extensión posterior con claves canónicas.
- Política de costo (FIFO/promedio) y stock negativo por flujo: hoy el SQL mezcla costo de compra y costo base. **Antes de habilitar el nuevo motor F2**, seleccionar y probar una política operativa precisa. Inicialmente registrar costo por unidad base y snapshots de transacción; no afirmar FIFO si no se ha implementado.
- Fiscalidad por país y multi-moneda: preservar capacidades existentes y snapshots; no crear ledger fiscal adicional en F1 sin requisito específico.
- Servicios físicos o mano de obra: se admiten como artículos comerciales sin stock; asignación de técnicos/recursos se difiere a un dominio específico.

---

### 10.11 ValidaciÃ³n F1 ejecutada en laboratorio aislado (2026-11-10)

Se creÃ³ el contenedor temporal `smoocontrol_f1_lab` con PostgreSQL 16,
roles Supabase mÃ­nimos, copia reproducible del contrato de tablas referenciado
y fixtures sintÃ©ticos de dos restaurantes. La carga del dump pÃºblico completo
fue descartada por lÃ­mite de memoria del contenedor (cÃ³digo 137), sin afectar
la base principal; la prueba continuÃ³ con el clon mÃ­nimo reproducible requerido
por el DDL. El contenedor y PostgREST temporal quedaron fuera de la base
principal.

**DDL:** `ITEM_CORE_F1_DDL_DRAFT.sql` ejecutado primero con `ROLLBACK` y sin
error despuÃ©s de aÃ±adir al clon los roles `authenticated` y `anon` que exige
el entorno Supabase. La segunda ejecuciÃ³n materializada con `COMMIT` ocurriÃ³
solo en el contenedor desechable; creÃ³ las siete tablas, restricciones,
Ã­ndices, RLS y grants del borrador. No se ejecutÃ³ en `supabase_db_smoo_control`,
producciÃ³n ni `main`.

**RPC experimental:** se aÃ±adiÃ³ fuera de `supabase/migrations`
`supabase/design/ITEM_CORE_F1_RPC_DRAFT.sql` con `app_upsert_item` y
`apply_item_movement`. Ambos son `SECURITY DEFINER`, fijan `search_path`, usan
claims JWT (`restaurant_id`, `permissions`, `role=service_role`), rechazan
cross-tenant y mantienen revocada la escritura directa de clientes. El arnés
`supabase/tests/item_master_f1_rpc_isolated.sql` exige
`app.f1_isolated=true` y termina en `ROLLBACK`.

Resultados verificables:

- SQL RPC: PASS para alta/ediciÃ³n, servicio sin stock, clasificaciones N:M,
  unidad base, idempotencia con mismo payload, rechazo de digest distinto,
  stock insuficiente, reversiÃ³n exacta y aislamiento cross-tenant.
- REST contra PostgREST temporal: `app_upsert_item` 200 y
  `apply_item_movement` 200; JWT sin permiso rechazado con HTTP 400.
- Concurrencia REST: dos ventas simultÃ¡neas de 2 sobre saldo 3 produjeron una
  respuesta 200 y una 400 por stock insuficiente; saldo final 1.
- El arnés guardado desde el repositorio terminÃ³ con
  `PASS item master F1 RPC assertions`, `ROLLBACK` y cÃ³digo 0.
- La ejecuciÃ³n directa del borrador DDL con `ROLLBACK` terminÃ³ con cÃ³digo 0.

**Problemas de editor y Flutter:** se corrigieron de forma local los futures
descartados y el acceso protegido de `articles_page_view_part.dart`, y se
ejecutÃ³ `dart format` sobre los archivos afectados. `dart analyze`,
`flutter analyze` y `flutter test` no devolvieron diagnÃ³stico: cada comando
quedÃ³ bloqueado mÃ¡s de 30 segundos en el analizador/entorno Dart y fue
detenido. Por tanto, no se declara el conjunto de 15 problemas ni el anÃ¡lisis
Flutter como aprobado; el bloqueo queda pendiente de un entorno limpio. Los
cambios locales preexistentes de UI, navegaciÃ³n, autenticaciÃ³n, localizaciÃ³n y
tests no se incorporan al commit F1.

**G1: NO APROBADO.** F1 queda validado estructuralmente en laboratorio aislado,
pero no habilita migraciÃ³n ni operaciÃ³n: falta resolver el anÃ¡lisis Flutter,
formalizar la prueba REST/concurrencia en CI, completar invariantes de unidades,
resolver consumo de reglas y contratos F2/Drift, y obtener revisiÃ³n de seguridad
de claims/grants antes de cualquier corte. La 088 sigue congelada y no aplicada.

**Commit publicado de esta ejecuciÃ³n:** `27b94c0`.

## 11. Referencias y precedencia documental

1. **Este plan rector**: fuente operativa de arquitectura, etapas, gates y estado actual.
2. **AUD-007** (`Documentation/Auditorias/AUD-2026-11-06-007-integracion-reorganizacion-empaques.md`): hallazgos originales y riesgos. La recomendación de catálogo virtual allí era **transitoria**; no prevalece sobre la decisión actual de core persistente.
3. **FE-E10** (`Documentation/Auditorias/FasesEmpaques/FE-E10-2026-11-10-maestro-articulos-db.md`): evidencia estática y descripción histórica de PR #18; su migración 088 permanece congelada.
4. **Investigación LS Central**: carpeta privada `POS` de Google Drive, `02-auditoria-integral-items-ls.md`, `01-resumen-arquitectura-items.md`, `00-fuentes-y-alcance.md`. Evidencia AL/SQL/hipótesis separadas.
5. **Microsoft Learn**: https://learn.microsoft.com/es-es/dynamics365/business-central/inventory-about-item-types (tipos de artículo; inspiración conceptual, no schema obligatorio).
6. Normas de implementación `AGENTS.md`, `CONTEXTO_PROYECTO.md` y QuantixEngineeringStandar aplicable.

**Jerarquía de autoridad:** requisitos acordados del core y este plan > contratos de seguridad/integridad verificados > historial de auditoría > soluciones transitorias de interfaz. Un PR o Codex no modifica la arquitectura por su cuenta. Cualquier contradicción se documenta aquí antes de ejecutar código.

## 12. Próxima acción autorizada

**Siguiente paso: validar el borrador DDL F1 sobre clon desechable con ROLLBACK, completar invariantes de unidades y permisos, y diseñar/ensayar `app_upsert_item` y `apply_item_movement` bajo aislamiento, antes de crear una migración efectiva.** Corregir el borrador con resultados de pruebas y documentarlos aquí. No aplicar la migración 088 espejo, ni tocar base real o pantallas.
