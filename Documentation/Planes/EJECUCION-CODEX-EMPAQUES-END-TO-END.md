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

### 10.12 F1.1 cierre de seguridad e integridad (2026-11-10)

La auditoria F1.1 se ejecuto contra un PostgreSQL 16 desechable, con PostgREST 12.2.3 y JWT HS256 firmados. No se ejecuto el DDL/RPC en `supabase_db_smoo_control`; la consulta de solo lectura al laboratorio principal confirmo que no existen `public.items` ni `public.item_ledger_entries`, y que `supabase_migrations.schema_migrations` no contiene version `088`. La migracion 088 esta expresamente NO aplicada y permanece congelada.

**Correcciones reproducibles aplicadas al borrador:** `app_item_has_write_access` ahora exige `auth.uid()`, `profiles`, `roles`, `role_permissions` y `permissions`, con usuario activo, rol activo, tenant exacto, no POS y permiso efectivo. `app_upsert_item` usa permiso `articulos.gestionar`; `apply_item_movement` usa `inventario.gestionar`. Se eliminaron los claims de permisos/tenant y el bypass `service_role`. Los `SECURITY DEFINER` fijan `search_path=public,pg_temp`, `row_security=off`, y se revocaron los helpers directos a roles cliente. El update parcial conserva atributos omitidos; se validan unidades activas, tenant/global scope, `unit_group`, conversion positiva y conversion base 1. Se bloquea cambiar tipo/unidad base despues de movimientos y desactivar con stock distinto de cero. El ledger calcula el digest canonico del contenido real, valida actor/dispositivo/origen, exige una sola reversa con cantidad y costo originales, usa lock de stock, bloquea negativos y verifica que la proyeccion coincide con `SUM(quantity_delta)`. Se agrego guardia append-only para UPDATE/DELETE.

**Resultados numericos de laboratorio:** 1 DDL ejecutado con `ROLLBACK` y 1 materializacion temporal con `COMMIT` solo en contenedor desechable; 7 tablas nuevas, 23 restricciones declarativas, 9 indices, 7 politicas RLS y 3 funciones/RPC revisadas en el contrato. La suite F1.1 obtuvo 7 grupos PASS: alta, update parcial, idempotencia, reversa, no negativo, cambio de unidad bloqueado y append-only; ademas PASS para separacion de permisos y rechazo POS. PostgREST acepto una alta con JWT real (`HTTP 200`, fila `REST-F11` creada en el contenedor). Los JWT de prueba no transportaron permisos: la autorizacion provino de las tablas del laboratorio. La prueba previa de concurrencia F1.0 mantuvo 1 exito y 1 rechazo, con saldo final 1.

**Dependencias no contempladas que siguen abiertas:** `products` y `packaging_items` aun tienen escritores y referencias legacy; faltan el corte de `product_recipes/product_recipe_lines`, `modifier_groups/options`, `sale_items`, compras, ajustes, consumo de personal/nomina, reportes y sincronizacion Drift. Tambien falta resolver el contrato de reglas `item_consumption_rules`/prioridad, snapshots de venta, origen POS/dispositivo en cada flujo, migracion de identidad de categorias y la auditoria completa de dependencias `pg_depend` antes de retirar tablas antiguas. Estas dependencias bloquean una activacion F2, aunque no invalidan la correccion aislada de los RPC F1.1.

**Matriz definitiva F1.1:** crear en una migracion futura: `items`, `item_classifications`, `item_classification_links`, `item_units`, `item_stock`, `item_ledger_entries`, `item_consumption_rules` y sus politicas/RPC. Modificar en corte coordinado: `product_categories`, `sales_types`, `measurement_units`, `profiles/roles/permissions`, recetas, modificadores, ventas, compras, nomina y payload/sync Drift. Eliminar solo despues de `pg_depend` y cero escritores: `product_packaging_rules`, `inventory_stock`, `packaging_stock`, `inventory_movements`, `packaging_movements`, `packaging_items`, `products`. En F1.1 no se creo, altero ni elimino estructura real, ni se modifico dato del laboratorio principal.

**Dart/Flutter:** `dart analyze`, `flutter analyze` y `flutter test` se ejecutaron una vez por comando y quedaron sin diagnostico despues de mas de 30 segundos; se detuvieron. La inspeccion de procesos mostro servidores Dart language-server, tooling-daemon, DevTools y un `flutter_tools` web-server concurrentes. No se repitieron indefinidamente ni se limpiaron caches; queda bloqueada la validacion completa en un entorno Dart limpio. Los cambios locales de UI/navegacion/auth/localizacion/tests permanecen sin stage.

**Decision G1: NO APROBADO.** F1.1 queda cerrado como auditoria de seguridad/integridad en laboratorio desechable, pero G1 no puede declararse aprobado por el bloqueo reproducido de Dart/Flutter y por las dependencias de ventas, recetas, nomina y sync aun no migradas/ensayadas. No se autoriza migracion, activacion operacional ni F2 desde este resultado.

**Cambios publicados:** RPC/test de diseno F1.1 y esta actualizacion documental; migracion 088, produccion, `main`, Tentrix, POS y pantallas no fueron tocados.

### 10.13 F1.2 cierre de validaciones y separacion G1/F2 (2026-11-10)

Se verifico la rama `feature/item-master-db-foundation` en `0d095ec718c234fe8d4cd610a486fb7806360124`, con remoto `origin` apuntando a `reySanchezDev/SmootControl`. Los cambios locales preexistentes de UI, navegacion, autenticacion, localizacion y tests permanecieron sin stage ni commit.

**Diagnostico Dart/Flutter:** Dart 3.11.5 y Flutter 3.41.7 stable. En el worktree limpio `flutter pub get` termino correctamente. `dart analyze` quedo en `Analyzing...` sin diagnosticos despues de 90 segundos; `flutter analyze` repitio el mismo estado despues de 90 segundos; el analisis dirigido de los archivos modificados tambien quedo bloqueado. No se observaron locks persistentes en `.dart_tool`. En el worktree original habia un `flutter run` web sobre otro worktree, dos analysis servers, tooling-daemon, DevTools, MCP Dart y varios procesos VS Code/Codex concurrentes; no se finalizo ninguno. Esto demuestra una condicion del analizador/entorno que se reproduce tambien aislada, no un error de compilacion demostrado del codigo.

**Resultados Flutter y formato:** `flutter test` en worktree limpio termino `All tests passed!`: 392 tests, 0 failures. Hubo una advertencia no fatal de hit-test en `pos_ready_view_test.dart`, sin fallo. `dart format --output=none --set-exit-if-changed .` termino exit 1 porque 40 archivos existentes requeririan formato; no se escribieron cambios. No se incorporaron modificaciones visuales ni se reabrieron los problemas locales no relacionados.

**Automatizacion F1:** `supabase/tests/item_master_f1_rpc_isolated.sql` queda como suite reproducible con rollback y guardia `app.f1_isolated`. Cubre permisos efectivos, revocacion inmediata, tenant, POS, update parcial, unidades, cambios incompatibles, stock negativo, idempotencia, reversas, proyeccion, append-only y escritura directa. La validacion REST con JWT HS256 firmado se ejecuto en PostgREST efimero y creo `REST-F11` con HTTP 200; el permiso efectivo se obtuvo de las tablas, no de claims de permisos. La prueba concurrente previa mantuvo una sola venta exitosa y rechazo por saldo insuficiente. El contenedor y PostgREST temporales fueron eliminados.

**Auditoria de seguridad final:** las funciones definer usan `auth.uid()`, `search_path=public,pg_temp` y `row_security=off`; los helpers de autorizacion no tienen EXECUTE para roles cliente; las RPC exigen permiso efectivo, usuario/rol activo, tenant exacto y no POS. No se acepta `service_role` ni permisos enviados por el cliente. El digest del ledger se calcula sobre el contenido canonico, el actor se ata a `auth.uid()`, el dispositivo se valida por tenant/estado, y los locks/constraint de operacion protegen idempotencia y reversas. No se detecto bypass reproducible en el contrato F1.1.

**Separacion de gates:** G1 valida exclusivamente el diseño, la seguridad y los contratos aislados del maestro de articulos. F2 integra ventas, recetas, compras, nomina, POS y Drift; no es requisito para aprobar G1, pero su corte coordinado sigue siendo requisito para activar el core. Por ello: **G1 APROBADO PARA PREPARAR F2**. Esto no autoriza migraciones, aplicacion de 088, escrituras operativas, eliminacion de legacy ni activacion en el laboratorio principal/produccion.

**Bloqueantes reales:** el analizador Dart/Flutter sigue sin resultado concluyente y el formato global tiene 40 archivos heredados; ambos quedan como higiene de toolchain antes de nuevos cambios de codigo. Para F2 siguen pendientes el mapa `pg_depend`, contratos de ventas/recetas/compras/nomina, snapshots, reglas de consumo, adaptador POS y sync Drift. Siguiente accion: preparar la matriz tecnica de corte F2 y resolver el entorno de analisis en una rama de implementacion separada, sin ejecutar migraciones.

## 11. Referencias y precedencia documental

1. **Este plan rector**: fuente operativa de arquitectura, etapas, gates y estado actual.
2. **AUD-007** (`Documentation/Auditorias/AUD-2026-11-06-007-integracion-reorganizacion-empaques.md`): hallazgos originales y riesgos. La recomendación de catálogo virtual allí era **transitoria**; no prevalece sobre la decisión actual de core persistente.
3. **FE-E10** (`Documentation/Auditorias/FasesEmpaques/FE-E10-2026-11-10-maestro-articulos-db.md`): evidencia estática y descripción histórica de PR #18; su migración 088 permanece congelada.
4. **Investigación LS Central**: carpeta privada `POS` de Google Drive, `02-auditoria-integral-items-ls.md`, `01-resumen-arquitectura-items.md`, `00-fuentes-y-alcance.md`. Evidencia AL/SQL/hipótesis separadas.
5. **Microsoft Learn**: https://learn.microsoft.com/es-es/dynamics365/business-central/inventory-about-item-types (tipos de artículo; inspiración conceptual, no schema obligatorio).
6. Normas de implementación `AGENTS.md`, `CONTEXTO_PROYECTO.md` y QuantixEngineeringStandar aplicable.

**Jerarquía de autoridad:** requisitos acordados del core y este plan > contratos de seguridad/integridad verificados > historial de auditoría > soluciones transitorias de interfaz. Un PR o Codex no modifica la arquitectura por su cuenta. Cualquier contradicción se documenta aquí antes de ejecutar código.

## 12. Estado operativo y ejecución automatizada (2026-11-10)

**F0:** ejecutada y auditada sobre PostgreSQL local. **G1:** aprobado para *preparar* F2, no para instalar schema ni operar en producción. La 088 espejo sigue congelada. Los módulos ventas, recetas, compras, consumo personal/nómina y Drift requieren corte coordinado.

### 12.1 GitHub Actions — automatización del trabajo remoto

- **Workflow:** `.github/workflows/item-core-quality.yml` — disparo en push de `feature/item-master-db-foundation`; PR contra `main` y ejecución manual según disponibilidad.
- **Inventario estático:** `tool/audit_item_core_dependencies.py`; analiza todas las migraciones versionadas y archivos Dart del proyecto, enumera las apariciones de siete tablas legacy y las últimas migraciones que contienen nombres de RPC. Publica el reporte como artefacto `item-core-dependency-inventory` (14 días).
- **Flutter:** instala Flutter stable **3.41.7** en runner Linux limpio, ejecuta `flutter pub get`, `flutter analyze --no-pub` con timeout explícito de 180 segundos y `flutter test --no-pub -j 2` con timeout de 1200 segundos. Los resultados no se ocultan; si falla/hang cualquiera, el job es fallido. Logs disponibles como artefacto `item-core-flutter-tooling-logs`.
- **Aislamiento:** workflow solamente hace checkout, lecturas de archivos, análisis de dependencias y pruebas Flutter. **No** conecta al PostgreSQL de laboratorio, no ejecuta migraciones, no necesita credenciales, no despliega y no escribe sobre `main`.
- **Importante:** la generación de mapa estático no equivale a resolver `pg_depend` real ni validar SQL ejecutado; debe complementarse con el censo F0 del laboratorio antes de eliminar tablas.
- **Estado al registrar:** workflow publicado y corridas lanzadas automáticamente por GitHub; resultados aún por certificar. No declarar PASS hasta tener `conclusion=success` y examinar logs.

### 12.2 Reparto de responsabilidad para reducir prompts Codex

**Trabajo del asistente mediante GitHub:** inspección de migraciones y Dart, matrices de dependencias, diseño/corrección de código versionado, commits, branches, PRs, configuración CI, revisión de logs, reportes y documentación de avance en este mismo plan. Los resultados de CI son evidencia de un entorno limpio de GitHub, no del Windows local.

**Trabajo exclusivo de Codex local:** acceso a `supabase_db_smoo_control` y `pg_catalog` vivo, inspección de colas/tickets de terminales, pruebas con dispositivos/Drift locales, pruebas que requieran Docker/Windows instalados en el equipo, ejecución de un futuro corte de laboratorio **solo tras autorización**. No delegar a Codex lo que pueda inspeccionarse/corregirse directamente en GitHub.

**Siguiente entrega técnica del asistente:** producir mapa F2 por tabla, función y consumidor desde el artefacto generado; construir contratos/versionamiento y PRs sin aplicar migraciones ni tocar pantallas. Si GitHub Actions no está habilitado o no corre, informarlo sin simular su ejecución. Resolver anomalías reproducibles del CI dentro de la rama.

**Gates:** G2 pendiente. Prohibido activar el nuevo core o retirar tablas legacy hasta que RPC, ventas/void, recetas, reglas, nómina, POS/Drift y sincronización superen pruebas y que no queden escritores legacy activos.

### 12.3 F2.0 — contratos concretos identificados en código (GitHub, no DB local)

**Evidencia:** inspección directa de `lib/features/sync/data/datasources/supabase_catalog_pull_service_catalog_part.dart`, `supabase_catalog_pull_service_inventory_part.dart`, `supabase_sync_remote_sender_payloads_part.dart`, `supabase_sync_remote_sender_sales_part.dart`, `lib/core/database/tables/catalog_tables.dart`, `inventory_tables.dart`, `sales_tables.dart`, `sync_tables.dart`, `app_database.dart`. Workflow `item-core-quality.yml` generó inventario estático satisfactoriamente en la corrida `42905726172`; pruebas Flutter completas pendientes a la hora de documentar. Este registro **no** equivale a pruebas de integración F2.

**Mapa de consumidores y reemplazos obligatorios:**

| Contrato efectivo actual | Evidencia en repositorio | Contrato F2 a implementar |
|---|---|---|
| Catálogo local | `LocalProducts`, `LocalPackagingItems`, `LocalProductPackagingRules` en `catalog_tables.dart` | `LocalItems`, `LocalItemClassifications`, `LocalItemUnits`, `LocalItemConsumptionRules`; ningún catálogo adicional de empaques |
| Existencias locales | `LocalInventoryStock`, `LocalPackagingStock` en `inventory_tables.dart` | `LocalItemStock` por `itemId`, cantidades `NUMERIC`/decimal sin redondeo a entero |
| Kardex local | `LocalInventoryMovements`, `LocalPackagingMovements` en `inventory_tables.dart` | `LocalItemLedgerEntries` por `itemId`, idempotencia, reversión y costo base |
| Descarga | `supabase_catalog_pull_service_catalog_part.dart`, `...inventory_part.dart`, `...missing_part.dart` | Pull **completo versionado** del maestro; visibilidad POS se calcula aparte; baja/inactivación solo tras snapshot completo del mismo tenant |
| Ajuste de saldo offline | `...inventory_part.dart` usa `pendingDeltas[productId]` y otra rama por `packagingItemId`; colas `sales`, `inventory_movements`, `packaging_movements` | Delta pendiente único por `itemId`, deduplicado por operación y fuente; tras ACK remoto no sumar nuevamente |
| Catálogo por envío | `supabase_sync_remote_sender_payloads_part.dart` genera estructuras separadas de producto, empaque y regla | Crear un único contrato DTO `item` + clasificaciones, unidades y reglas; no enviar dos maestros ni convertir códigos a UUID |
| Venta remota | `supabase_sync_remote_sender_sales_part.dart` hace upsert de `sales`, luego `sale_items`, luego movimientos de inventario y empaque | **Reemplazar por RPC transaccional única** de venta/void o comando idempotente de operación. Prohibido mantener mutaciones HTTP separadas que puedan quedar parcialmente aplicadas |
| Línea de venta | `_saleItemPayload` envía `product_id` y usa `productId` como `product_code` | `item_id` UUID y `item_code` comercial reales, snapshot inmutable de código/nombre/precio/costo/unidad/modificadores |
| RPC POS del servidor | `pos_sync_sale` / `pos_sync_staff_consumption`, rediseñadas en varias migraciones 019–065 | Nueva versión de contrato JSON con `schema_version`, tenant/terminal y `item_id`; evitar dobles caminos POS web/RPC que contabilicen la misma operación |
| Reglas | `product_packaging_rules` y `sales_types` | `item_consumption_rules` con regla aplicable explícita `per_order` o `per_sale_line`, prioridad determinista y snapshot de consumo registrado |
| Empleados/nómina | `employee_raw_material_consumption_lines.product_id` y RPC `app_*raw_material*` | Línea por `item_id`, movimientos de staff canónicos, no cambiar cálculo de nómina ni tipos de documentos |
| Ajustes/compras/recetas | `inventory_adjustment_lines.product_id`, `product_recipe_lines.component_product_id`, `app_register_inventory_purchase_batch` | FK canónicas `item_id`, validación de unidades y uso de `apply_item_movement` en una única transacción |

**Hallazgo de riesgo principal:** el sender `supabase_sync_remote_sender_sales_part.dart` realiza escrituras HTTP sucesivas sobre cabecera, líneas y movimientos. La idempotencia del ledger F1 por sí sola **no hace atómica la venta completa**. F2 debe tener **un único comando transaccional** para venta/void; conservar el sender anterior durante el corte sin adaptarlo permitiría estados parciales o doble aplicación.

**Orden de implementación F2 recomendado (no paralelizar cortes de autoridad):**

1. **F2.1**: definir/ensayar `item_consumption_rules` resolver y comandos SQL transaccionales `pos_sync_sale_v2` / void; fijar snapshots, política de costo base y negativos, algoritmo de idempotencia de operación completa. Probar en Docker desechable.
2. **F2.2**: reconducir recetas, modificadores, compras/ajustes y consumo de personal/nómina hacia `item_id` y ledger único; pruebas de compatibilidad/contabilidad.
3. **F2.3**: crear versión nueva de Drift y DTO de pull/push para `LocalItems`, `LocalItemStock`, `LocalItemLedgerEntries` y reglas, con flags de versión/corte; verificar todos los consumidores y tests offline.
4. **F2.4**: ejecutar **ensayo de corte aislado**: snapshot/configuración útil, migrar maestro real, reset solo de historial sintético consentido en laboratorio clonado, desconectar terminal v34 o migrarlo, verificar colas/tickets, activar RPC canónicas, prohibir escritores legacy, completar `pg_depend` y retirar tablas obsoletas sin CASCADE. No usar producción.
5. **G2**: solo aprobable con una venta y una anulación end-to-end, receta, empaque por pedido/línea, compra, ajuste, nómina, dos terminales concurrentes, modo offline y reenvío idempotente, permisos efectivos por tenant, y cero rutas funcionales que escriban masters/ledgers legacy.

**Próxima acción ejecutable remotamente:** implementar el arnés de contrato para `pos_sync_sale_v2` y resolvedor de reglas en `supabase/design/`, fuera de migraciones, con test aislado y verificación GitHub Actions. No aplicar en el laboratorio real antes del ensayo de corte. Codex solo cuando haga falta acceder a Docker/Windows/terminales locales.


### 12.4 Primer cierre de evidencia CI y diagnóstico remotos (2026-11-10)

**GitHub Actions** `Kivo Item Core - Quality and Dependency Inventory`. Ejecución completada `42905566927` (commit anterior `f86b91dc...`) con inventario de dependencias **PASS** y calidad Flutter **FAIL por diagnósticos de análisis**, no por bloqueo ni por tests. Los logs muestran:

- Flutter 3.41.7; `flutter analyze --no-pub` **terminó en 30.4 s**, exit **1** y **33 issues**, entre ellos un warning `invalid_use_of_protected_member` en `articles_page_view_part.dart:79` y el resto observaciones estilo/import/futures/tests. **No equivale a PASS**.
- `flutter test --no-pub -j 2`: **392 tests PASS**, exit 0, sin fallos. Runner limpio Linux elimina la hipótesis de que el análisis no puede finalizar en ningún entorno; Windows sigue requiriendo diagnóstico propio.
- La ejecución completa marcó FAIL correctamente en `Enforce quality without masking analyzer hangs`, porque el analizador devolvió código 1. No se aceptan los diagnósticos como nuevos defectos de F2 sin inspeccionar el baseline y el worktree local.
- Se corrigió el workflow para **no ejecutar en commits de solo documentación** y evitar cancelaciones redundantes del trabajo de CI; `concurrency` ya reduce repeticiones en la misma rama. La corrida en el commit final del workflow debe consultarse antes de considerarla aprobada.
- Las correcciones de estilo/UI **no se hicieron en GitHub** debido a los cambios locales existentes reportados en esos archivos. Se requiere comparar ramas y prevenir pérdida del trabajo no publicado antes de tocar los mismos archivos. La advertencia de miembro protegido es prioritaria y deberá solucionarse sin alterar UX.

**Siguiente trabajo F2 bajo GitHub:** avanzar implementación aislada de contratos SQL de venta/void transaccional y resolución de consumo; tests en runners efímeros donde exista esquema sintético adecuado, sin migración a principal. Ejecutar diagnóstico detallado de las 33 incidencias en una rama de limpieza separada, sin alterar código local sin publicar.

### 12.5 F2.1 — Resolvedor de reglas implementado y probado en CI (2026-11-10)

**Artefactos SQL fuera de migraciones:**
- `supabase/design/ITEM_CORE_F2_CONSUMPTION_DRAFT.sql`: RPC de **consulta** `resolve_item_consumption(restaurant_id,sales_type_id,lines JSONB)`, `SECURITY INVOKER`, tenant cotejado con `current_restaurant_id()`, filtrado por artículos vendibles, reglas activas y artículos consumibles inventariables. No modifica inventario, ventas ni recetas.
- `supabase/tests/item_core_f2_consumption_isolated.sql`: dataset de dos restaurantes en transacción **ROLLBACK**; prueba por línea, pedido, prioridad global versus específica, agregación de líneas repetidas, conflicto de reglas igualmente prioritarias, unidades incompatibles y tenant cruzado.
- `.github/workflows/item-core-quality.yml`: job PostgreSQL 16 en contenedor efímero, sin Supabase local ni secrets, que ejecuta SQL con `psql -X -v ON_ERROR_STOP=1`.

**Evidencia CI:** ejecución `42907316625`, job `F2 consumption rule SQL - isolated PostgreSQL`, **success**; dependencia estática, **success**. El primer intento detectó el rol `anon` ausente del fixture (no era defecto del servidor). Se corrigió el fixture y volvió a ejecutar PASS. El test de mayor especificidad por pedido añadido después debe aprobar en su corrida específica antes de darse como certificado.

**Contrato de resolución:** tipo de servicio exacto prevalece sobre wildcard; dentro de ello artículo origen específico prevalece sobre global y después `priority` menor; empate del mejor rango para mismo consumo/scope se rechaza, en vez de duplicar. `per_order` se ejecuta exactamente una vez; `per_sale_line` multiplica cantidad agregada; unidades convierten por `base_factor` solo dentro del mismo grupo físico. La aplicación debe persistir la resolución y el snapshot dentro de **la misma transacción que el cobro**. La resolución aislada no satisface por sí sola la operación F2 completa.

**Riesgos a resolver antes de G2:** el resolver es `SECURITY INVOKER` y requiere que la identidad de restaurante esté resuelta por backend; se debe ensayar con JWT de POS reales y las políticas finales `items/item_consumption_rules`, no únicamente con `app.test_restaurant` del test sintético. También se deben probar la validación de reglas para artículos no inventariables y un error explícito cuando una regla seleccionada no puede consumirse; no permitir omisiones silenciosas.

**Punto de integración crítico:** el `pos_sync_sale` actual es una cadena de wrappers, no una función monolítica: migración 019 construye numeración remota, 052 añade reversión de receta, 054 snapshot histórico y 065 un guard de dispositivo/caja; 084 agrega trigger de snapshot de anulación. F2 debe **sustituir el contrato mediante `pos_sync_sale_v2`**, con una sola transacción, no envolver indefinidamente el stack legacy. El endpoint nuevo debe validar dispositivo y caja, asignar número remoto, grabar cabecera/líneas snapshot, resolver consumo, registrar ledger y confirmar idempotencia sin escrituras HTTP parciales. La anulación debe revertir el ledger **contabilizado en la venta original** una sola vez.

**Próxima implementación concreta:** contrato SQL transaccional de venta/void con identificación de operación y payload canónico, luego prueba en esquema completo clonado o esquema contractual equivalente; ningún SQL del borrador se aplicará a bases operativas antes de G2.

### 12.6 F2.2 — Documentos de compra y ajuste unificados (borrador de contrato)

**Rama aislada:** `feature/item-core-f2-purchases-adjustments`, PR #19 contra la rama técnica de artículos (no contra `main`). DDL/RPC `supabase/design/ITEM_CORE_F2_STOCK_DOCUMENTS_DRAFT.sql`, fixture y aserciones aisladas `supabase/tests/item_core_f2_stock_document_{fixture,assert}.sql`.

**Diseño comprobable:** un solo comando `app_post_item_stock_document_v2` para documento `purchase` o `adjustment`, ambos con `item_id` y `item_core_internal.post_movement` como **único motor de stock**. `item_inventory_operations` registra idempotencia por documento/reintento; rechazo de documento repetido con payload distinto, rollback total si falla una línea, validación de inventariable/comprable, conversión de unidad de compra a unidad base y costo unitario base, rechazo de precisión perdida y de cantidades duplicadas, conteo esperado y stock bajo lock de fila antes del ajuste. Ninguna escritura en `products`, `packaging_items` ni en los dos ledgers antiguos.

**Evidencia automatizada:** la primera corrida GitHub Actions `42913704982` aprobó el job de PostgreSQL aislado **antes** del endurecimiento de lock. El lock se corrigió después y requiere la corrida del nuevo SHA. El workflow también ejecuta inventario estático, consumo, receta y venta/void; Flutter se ejecuta solo cuando los cambios afectan Dart o su workflow.

**Límites explícitos:** este documento no implica compras listas para producción. No se han integrado proveedor, factura de compra, impuestos, multimoneda, autorización con JWT real en el esquema completo, almacenes ni POS/Drift. La fixture usa un adaptador sintético de permisos; no sustituye la validación F1.1 JWT y RLS. El DDL sigue **fuera de migraciones** y PR en borrador. No activar el contrato antes del corte integral F2 ni retirar tablas legacy.

**Gate:** G2 continúa pendiente. La operación de inventario y el documento deben reconciliar saldos y permisos cuando se prueben sobre el esquema completo; la ruta de escritura antigua seguirá deshabilitada únicamente tras corte coordinado.

### 12.7 F2.2 — Consumo de materias primas del personal, sin borrar el libro

**PR técnico:** #20, `feature/item-core-f2-staff-consumption` hacia `feature/item-master-db-foundation`. Borrador `supabase/design/ITEM_CORE_F2_STAFF_CONSUMPTION_DRAFT.sql` y arnés `supabase/tests/item_core_f2_staff_consumption_{fixture,assert}.sql`, todos fuera de migraciones.

**Cambio operativo definido:** la RPC antigua `app_save_raw_material_staff_consumption` (migración 074) modificaba el stock manualmente, borraba sus movimientos y líneas, y las volvía a insertar al editar. Esa semántica es **incompatible** con el ledger append-only y las anulaciones auditables del nuevo core. La sustitución F2 usa:
- `app_post_staff_item_consumption_v2` — una operación idempotente por `restaurant_id+operation_key`, líneas por `item_id` con clasificación `raw_material`, unidad validada y conversión decimal, importe basado en costo unitario base del maestro, snapshots por línea y **movimiento del ledger** mediante `item_core_internal.post_movement`.
- `app_void_staff_item_consumption_v2` — anulación idempotente que crea movimientos inversos de los **movimientos originales contabilizados**; no DELETE/UPDATE del ledger. Bloquea anulación si `payroll_run_id` está asignado; conserva `total_amount` como snapshot.
- Encabezado existente `employee_raw_material_consumptions` se **extiende** con `status`, claves/digest de operación y void; las líneas se reconducen a `item_id` en corte coordinado, retirando FK y `product_id` antiguos. **No crear otro maestro de consumos ni cambiar manualmente registros de nómina históricos.**
- Los RPC de nómina `app_get_employee_raw_material_payroll_total` y `app_mark_raw_material_consumptions_paid` deben considerar únicamente `status='posted'` y realizar validación de tenant/permiso y bloqueo de registros antes de asociar planilla. **Todavía no se ha modificado nómina**, por lo que el contrato no puede activarse.
- Prueba SQL: consumo 2 cajas de 12 a costo 3 base = cantidad base 24, importe 72; replay sin duplicar; rechazo de payload alterado, usuario sin permiso, empleado cross-tenant, servicio como ingrediente; void revierte +24 sin borrar snapshot y no permite anular una línea asignada a planilla. Prueba contra schema **sintético**, no contra todos los payroll RPC efectivos.

**CI:** GitHub Actions ejecuta job `F2 staff consumption and void - isolated PostgreSQL` con PostgreSQL 16 desechable y `ROLLBACK`. El primer resultado de este job fue PASS en la corrida `42915516379`; cualquier modificación posterior requiere una nueva corrida PASS antes de fusionar. Las validaciones SQL no sustituyen pruebas de payroll con permisos reales/JWT ni consistencia de pago final.

**Estado:** contrato de diseño F2.2, no desplegado. No aplicar en base principal/producción ni habilitarlo desde UI/POS hasta que nómina, permisos efectivos, Drift y ventas completen G2.

### 12.8 F2.2 — Reclamación de consumos de personal para nómina

**Entrega técnica:** `feature/item-core-f2-payroll-claim`, archivos `supabase/design/ITEM_CORE_F2_PAYROLL_CLAIM_DRAFT.sql` y `supabase/tests/item_core_f2_payroll_claim_{fixture,assert}.sql`, y job PostgreSQL 16 desechable en GitHub Actions. **No ejecutado en base operativa ni migraciones**.

**Decisión de integridad:** el contrato heredado 076/077 calcula el total de materia prima y después marca filas como pagadas mediante llamadas separadas. F2 sustituirá esta separación por un **claim único y transaccional**, que devuelve exactamente las filas e importes asignados a `payroll_run_id`, ignora `status='voided'`, bloquea reclamación por otro run, aplica período semiabierto `[inicio,fin)` y toma lock por empleado compartido con los RPC de creación/anulación del consumo.

**Decisión de seguridad incorporada tras auditoría:** el claim acepta límites temporales pero NO debe quedar invocable como endpoint REST independiente. Se implementa como `item_core_internal.claim_staff_consumptions_for_payroll`, sin `EXECUTE` para `anon`/`authenticated`. Lo llamará exclusivamente la RPC confiable `app_post_payroll_employee` después de validar usuario, tenant, período real de `payroll_runs`, zona horaria comercial y estado draft. El test aislado afirma que un usuario `authenticated` **no puede** invocarlo. Nunca dar permisos de cliente directo ni usar un `set_config` del cliente como autorización.

**Dependencias que aún obligan a corte conjunto:**
1. Actualizar `app_post_payroll_employee` para calcular y marcar consumos en **una operación**, usando el total y detalle del claim como snapshot de nómina. Hoy se conserva la función legacy sin modificar.
2. Definir origen de zona horaria por restaurante; `payroll_runs.period_start/period_end` son `date`, pero `consumed_at` es `timestamptz`. La RPC superior debe convertir el rango local a instantes UTC y demostrar que no puede reclamar ventanas distintas de las fechas del run. **No resolver con UTC fijo para todos los restaurantes.**
3. Evitar crear consumos retroactivos en períodos ya liquidados: el lock impide carrera durante el claim, **pero no impide inserción tardía después del commit**. La RPC de registro deberá comprobar `payroll_run_lines` y periodos liquidados del empleado.
4. Ajustar `app_reverse_payroll_payment_receipt` para liberar solo consumos realmente asociados a ese run y preservar snapshots/liquidaciones.
5. Asegurar que la operación de pago/reversión completa conserva condiciones de nómina parcial, adelantos, horas extras y comprobantes existentes (migraciones 022–079).
6. Ejecutar pruebas JWT/RLS y flujo real con la totalidad del esquema de nómina, no solo la fixture sintética.

**Pruebas del contrato:** consumos válidos, anulados, fuera del límite superior, repetición, reclamación de otro run, permisos independientes, tenant cruzado, run ya publicado, void de consumo asignado, reconciliación del kardex. Solo afirmar PASS en el SHA cuyo job GitHub Actions tenga conclusión exitosa.

**Gate G2:** sigue ABIERTO. La integración es un borrador SQL aislado y seguro por ausencia de despliegue; no autoriza modificaciones de UI, POS, base principal, `main` ni migración 088.

### 12.9 F2.2 — Bloqueo de consumos retroactivos en períodos de nómina ya liquidados

**Rama de trabajo:** `feature/item-core-f2-payroll-backdate-guard`. El contrato F2 de consumo de personal se amplió para consultar el calendario de `payroll_runs` + `payroll_run_lines` del empleado, bajo el mismo advisory lock que utiliza el claim de planilla. Si la fecha **local del restaurante** cae dentro de un período con línea de nómina `draft` o `posted`, rechaza nuevas altas retroactivas. Un replay exacto de un consumo previamente contabilizado devuelve el resultado original antes del guard, sin duplicar el ledger.

**Zona horaria:** se lee exclusivamente de `business_rules(key='business_timezone', text_value=<IANA>)`, configurada por restaurante y validada contra `pg_timezone_names`. Si falta o es inválida, la RPC **falla cerrada**; se debe aprovisionar este valor en el futuro corte F2. No utilizar la zona horaria del dispositivo, la sesión SQL ni UTC como sustituto silencioso.

**Prueba de borde real:** 2026-11-16 05:59 UTC equivale al 15 de noviembre a las 23:59 en `America/Managua` y **debe rechazarse** si esa quincena ya tiene línea de nómina. 2026-11-16 06:00 UTC es el inicio del 16 de noviembre local y no pertenece al período anterior. Tests de staff y claim ejecutados en PostgreSQL 16 desechable con ROLLBACK.

**Límites:** la protección no pretende modificar ni borrar planillas antiguas; no sustituye la validación del rango temporal del run dentro del RPC de pago definitivo, ni pruebas de nóminas parciales y reversión de comprobantes. Los contratos `item_core_internal.claim_staff_consumptions_for_payroll`, `app_post_staff_item_consumption_v2` y `app_void_staff_item_consumption_v2` deben implantarse de forma coordinada y no autorizarse como endpoints nuevos antes de G2.

**Validación GitHub Actions:** corrida `42918534477`; jobs staff consumption, payroll claim, consumo, compra/ajuste y recetas **PASS**. Flutter se omitió correctamente por no existir cambios Dart. Un commit documental posterior no modifica el comportamiento SQL verificado.

**Gate G2:** ABIERTO. No se aplicó ninguna migración ni se modificaron tablas en el laboratorio/producción.

### 12.11 F2.1 — Empaques no inventariados y venta/anulación

**Rama:** `feature/item-core-f2-noninventory-consumption`. Durante la auditoría cruzada F2.1/F2.3 se detectó que `resolve_item_consumption` filtraba exclusivamente `consumed.item_type='inventory'`, **omitiendo silenciosamente servilletas/empaques no inventariados**, aunque el core admite ese tipo y su clasificación como empaque.

**Corrección de contrato:** se resuelven consumos de `inventory` y `non_inventory`, con rechazo explícito de reglas activas hacia `service`. En `pos_sync_sale_v2`, solo artículos `inventory` crean movimiento físico; ambos tipos se registran en el snapshot original de venta. `sale_consumption_snapshots.is_inventory_consumption` + `movement_id` nullable de modo consistente distinguen consumo físico y lógico; la anulación revierte **solo** movimientos físicos originalmente contabilizados. **No se inventan existencias para artículos no inventariados.**

**Pruebas PostgreSQL 16 aisladas:** resolver no omite artículos no inventariados, rechaza servicios, compra/ajuste/recetas/nomina siguen pasando; venta de botella con bolsa inventariable `per_order` y servilleta no inventariable `per_sale_line`: dos snapshots, pero solo dos movimientos físicos (producto y bolsa); void devuelve stock a apertura y conserva snapshots. **CI corrida `42921236410`: success.**

**Seguridad pendiente:** la señal `is_inventory_consumption` del snapshot es derivada por RPC confiable del `item_type`. En el corte definitivo debe denegarse DML directo a `sale_consumption_snapshots`, impedir RPC alternativos que creen snapshots falsificados y verificar FK/trigger frente al esquema real y JWT. Este SQL continúa exclusivamente en `supabase/design/`, no en migraciones ni base principal.

**Estado:** contrato integrado en rama técnica solo tras suite CI; G2 continúa ABIERTO hasta integración real de POS, Drift, permisos y cutover.

### 12.12 F2.3 — Contrato de catálogo POS V2, previo a migrar Drift

**Rama:** `feature/item-core-f2-pos-catalog-validated`, desde `feature/item-master-db-foundation`. Se agregan exclusivamente código Dart **independiente** del motor actual y pruebas:
- `lib/features/sync/domain/entities/item_catalog_snapshot_v2.dart`
- `test/features/sync/domain/entities/item_catalog_snapshot_v2_test.dart`

**Alcance:** modelo inmutable de snapshot completo del maestro `items`, conversiones `item_units` y referencias de `item_consumption_rules`. Exige `contract_version=2`, `snapshot_complete=true`, `restaurant_id` uniforme, revisión positiva, `snapshot_id` estable, UUID canónicos, códigos comerciales únicos sin distinguir mayúsculas/minúsculas, unidad base por artículo con factor 1, conversiones decimales exactas representadas como **cadenas** y reglas que solo apuntan a artículos/unidades del mismo catálogo. Prohíbe convertir un artículo oculto de POS en artículo borrado/inactivo. Una respuesta paginada/parcial se rechaza **antes de tocar SQLite**.

**Idempotencia/snapshot:** si la revisión entrante es menor que la aplicada se rechaza por stale; si es igual con el mismo `snapshot_id` se considera replay sin cambio, y si es igual con `snapshot_id` diferente se rechaza. Una revisión superior solo se considera aplicable; **NO se ejecuta todavía ninguna escritura Drift**. La futura actualización debe ser una transacción local única que persista artículos, unidades, reglas y revisión juntos.

**Pruebas:** casos de catálogo de hamburguesa no inventariable y empaque inventariable compartiendo el maestro; partial-pull; cross-tenant; código duplicado; unidad base ausente/factor distinto de uno; regla a unidad inválida; precisión decimal; servicio como consumo físico; line-rule sin origen; revisiones repetidas, desordenadas y conflictivas; listas inmutables.

**Preocupaciones de integración antes de G2:**
1. Crear `pos_pull_item_catalog_v2` transaccional y snapshot completo con revisión monotónica por restaurante. `snapshot_id` debe identificar exactamente la misma revisión; no confiar en que el cliente pueda crear revisiones.
2. Completar el parser de reglas, atributos vigentes y modificaciones POS existentes necesarios para no degradar funcionalidad. El contrato actual es **un núcleo mínimo**, no un DTO exhaustivo de todos los campos de la venta.
3. Adaptar Drift v34 a tablas canónicas en una rama controlada, sin correr ambas rutas `LocalProducts`/`LocalPackagingItems` al mismo tiempo. Los dispositivos offline deben cerrar/enviar pendientes o reinstalar base de prueba antes del corte.
4. Cambiar el sender de ventas al comando transaccional V2; no basta con sincronizar un catálogo nuevo manteniendo envíos HTTP parciales anteriores.
5. GitHub Actions debe comprobar tests y análisis de los archivos nuevos; si el análisis global falla por defectos legacy, separar la línea base y demostrar cero diagnósticos **nuevos**. No registrar G2 como aprobado por pruebas DTO.

**CI:** se corrigió la detección de cambios Dart para incluir el diff completo de una rama F2 contra la rama de integración, y no solamente el último commit (que podría cambiar YAML y omitir pruebas). Verificar conclusión del run de esta rama antes de considerar certificado el contrato.

### 12.13 F2.3 — Calidad CI sin ocultar el análisis global (2026-11-10)

**Incidencia resuelta en el gate:** GitHub Actions `42921763903` completó 392+ pruebas Flutter con exit 0, pero `flutter analyze` devolvió exit 1 por **33 diagnósticos heredados** (1 warning `invalid_use_of_protected_member`, 32 info). El código nuevo del contrato POS V2 no añadió ningún diagnóstico en esta corrida. Esto NO equivale a un análisis global exitoso.

**Control implementado en la rama F2.3:** `tool/item_core_analyzer_baseline.json` congela los diagnósticos por ruta/código/severidad/cantidad, con referencia explícita al run de origen; `tool/check_item_core_analyzer.py` exige un análisis terminado normalmente y **falla si aparece un diagnóstico nuevo o aumenta cualquiera de los existentes**. También exige coincidencia entre el número de diagnósticos analizados y el resumen del compilador. No permite pasar timeouts, crashes ni fallos de `flutter test`. Adicionalmente, Actions ejecuta `dart analyze` **directamente sobre los dos archivos nuevos F2.3**, que deben estar limpios.

**Interpretación de CI:** un run verde significa pruebas exitosas, código F2.3 limpio y **sin regresiones contra un baseline heredado**. NO significa `flutter analyze` global limpio. Los 33 diagnósticos siguen siendo deuda reconocida y deberán desaparecer del baseline mediante una corrección separada y verificable; nunca aumentar ni sustituirlos por excepciones del analizador.

**Restricción:** no se modificaron páginas UI o tests preexistentes en esta fase, pues su estado local podía contener cambios no publicados. G2 sigue pendiente y el catálogo V2 continúa sin integrarse en Drift/POS operativos.

### 12.14 F2.3 — Snapshot canónico POS desde servidor (diseño SQL)

**Rama técnica:** `feature/item-core-f2-pos-catalog-server`. Nuevo contrato `supabase/design/ITEM_CORE_F2_CATALOG_PULL_DRAFT.sql`, fixture `supabase/tests/item_core_f2_catalog_pull_fixture.sql`, aserciones `supabase/tests/item_core_f2_catalog_pull_assert.sql`, y job CI PostgreSQL 16 aislado. Todo continúa **fuera de `supabase/migrations`**, sin afectar PostgreSQL principal, producción o la sincronización POS existente.

**Contrato de lectura:** `pos_pull_item_catalog_v2(restaurant_id,device_id,device_secret)` verifica terminal/tenant con `assert_pos_device`, toma `FOR SHARE` sobre revisión del catálogo del restaurante y devuelve un solo JSON completo (`contract_version=2`, `snapshot_complete=true`, `snapshot_id`, `revision`, todos los `items` —incluidos inactivos y ocultos del POS—, `item_units` activas y `item_consumption_rules` activas). Se rechaza un snapshot con unidad base inválida o regla que consuma un servicio, artículo inactivo o unidad inexistente. Los códigos comerciales, clasificación de inventario y visibilidad POS no se confunden entre sí.

**Autoridad de revisión:** `item_catalog_revisions` mantiene `revision` estrictamente positiva y `snapshot_id` de cada restaurante. El helper privado `item_core_internal.bump_item_catalog_revision` actualiza la revisión y el identificador de snapshot, sin grants de ejecución a clientes. La escritura **NO es segura** hasta que todas las RPC canónicas que cambien artículos, unidades, clasificaciones y reglas tomen un lock `FOR UPDATE` de esa revisión **ANTES** de mutar y la incrementen en la misma transacción. Un solo escritor que omita ese protocolo puede crear inconsistencias. Esta condición es un **bloqueante de G2**, no un detalle opcional.

**Ensayos:** el test aislado valida catálogo completo (producto vendible, empaque inventariable, artículo no inventariable y servicio), reglas por línea/pedido, revisión/id repetible, incremento monotónico, credenciales POS, cross-tenant, fallo por unidad base ausente y ausencia de escritura cliente sobre la revisión.

**Advertencia:** el primer diseño no incorpora modificadores, precios avanzados, clasificaciones N:M ni todos los campos que requiere una pantalla POS existente; el contrato V2 es un primer esquema de exportación y NO debe conectarse a Drift hasta confirmar todos los consumidores. Aún se requieren pruebas con el esquema completo, fixtures JWT/RLS reales, colas offline y adaptación transaccional del motor sync. G2 permanece ABIERTO.

### 12.15 Integración remota F2.3 (confirmaciones de GitHub)

- **PR #25:** integrado a `feature/item-master-db-foundation` mediante squash `b4a6db60ad433669d4620ce8f1d283b0ac1a91a6`. Contrato Dart del catálogo canónico + pruebas, detección de regresiones del analizador y análisis focalizado de los nuevos archivos. El run `42933731220` obtuvo todos los jobs **success**, incluyendo el guard de **33 diagnósticos legacy como máximo** y las pruebas Flutter. Esto NO significa que `flutter analyze` global esté libre de advertencias.
- **PR #26:** integrado a la misma rama técnica mediante squash `0f8129301eb8e63b38c57b53c021a69fe51cd2df`. Exportación POS V2 completa del maestro con revisión y snapshot por tenant, bajo prueba PostgreSQL 16 aislada. El run `42934670518` obtuvo **success** en todos los jobs aplicables; Flutter se omitió porque el commit es exclusivamente SQL.
- **Bloqueante técnico principal vigente:** la revisión monotónica del catálogo requiere adaptar **todos los escritores** del maestro, unidades, clasificaciones y reglas para tomar el lock sobre `item_catalog_revisions` antes de sus cambios y actualizar la revisión en la misma transacción. No conectar todavía el pull a Drift ni habilitar los RPC de escritura antes del corte coordinado.
- **Próximo trabajo remoto:** adaptar el escritor `app_upsert_item` y las mutaciones de reglas/unidades al protocolo transaccional de revisión, comprobar rollback/idempotencia/tenant en PostgreSQL desechable y posteriormente preparar la versión nueva de Drift. No autorizar aplicar migraciones en laboratorio principal ni producción hasta G2.

### 12.16 F2.3 — Puente transaccional del escritor de artículos

**Artefactos aislados:** `supabase/design/ITEM_CORE_F2_CATALOG_WRITER_BRIDGE_DRAFT.sql`, fixture y test `supabase/tests/item_core_f2_catalog_writer_{fixture,assert}.sql`, GitHub Actions PostgreSQL 16. Sin migraciones aplicadas.

**Contrato de escritura:** `app_upsert_item_v2` verifica `articulos.gestionar`, exige una revisión inicializada, adquiere `FOR UPDATE` sobre `item_catalog_revisions` **antes** de llamar a la RPC F1 `app_upsert_item`, y actualiza `revision`/`snapshot_id` dentro de la **misma transacción**. La denegación/revocación de `EXECUTE` sobre la RPC antigua evita que un usuario cliente eluda el protocolo. La función V2 es un **puente de corte**, no un segundo maestro permanente; deberá consolidarse con el escritor canónico una vez completado F2. Los otros escritores (unidades/reglas/categorías/clasificaciones) todavía deben implementar el mismo protocolo.

**Aserciones aisladas:** cambiar el nombre de un artículo produce revisión +1 y un nuevo snapshot; falla de escritura no cambia artículo ni revisión; permiso insuficiente rechaza; `authenticated` ya no puede ejecutar directamente la RPC antigua y sí tiene habilitada la nueva. **El fixture de este test representa un escritor F1 simplificado**; no sustituye la suite de seguridad F1.1 con roles reales ni ensaya la integración SQL completa.

**Regla G2:** mantener escritura canónica y revisionado coordinados. El catálogo V2 sigue desconectado de Drift y del POS activo; producción y la base principal permanecen intactas.
