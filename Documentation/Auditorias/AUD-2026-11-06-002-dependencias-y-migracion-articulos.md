# AUD-2026-11-06-002 — Dependencias y transición al maestro de artículos

**Fecha:** 2026-11-06 · **Tipo:** auditoría estática de código, solo lectura · **Estado:** documentación terminada; verificaciones de entorno real abiertas.  
**Repositorio:** `reySanchezDev/SmootControl` · **Rama examinada:** `develop/backoffice-stabilization-integration` · **SHA del árbol:** `7ce5163e0c6e698397dca0f57689966a4b714649`.  
**Auditoría precedente:** [AUD-001](AUD-2026-11-06-001-maestro-articulos.md). Esta auditoría profundiza dependencias y riesgos; evita repetir los hallazgos generales.

> Prohibido interpretar este documento como autorización para modificar SQL, Flutter, inventario, datos, POS o producción. No se ejecutaron comandos Flutter, SQL, tests ni consultas sobre Supabase vivo. El despliegue operativo puede diferir de esta rama.

## 1. Inventario de entidades y contratos

| Dominio | Drift/SQLite local | Supabase versionado | Consumidores y contratos |
|---|---|---|---|
| Productos | `LocalProducts` en `lib/core/database/tables/catalog_tables.dart` | `public.products` (001; clasificación `product_kind` y posteriores 041–043, 048, 060) | `Product`, `LocalProductsDataSource`, POS, receta, reportes, sync |
| Empaques | `LocalPackagingItems` | `public.packaging_items` (009) | `PackagingItem`, admin remoto, POS |
| Tipos de venta | `LocalSalesTypes` | `public.sales_types` (009) | selector ticket POS, `LocalSales.salesTypeId` y `salesTypeName` |
| Reglas de empaque | `LocalProductPackagingRules` | `public.product_packaging_rules` (009) | producto + tipo venta + empaque + cantidad |
| Modificadores | `LocalModifierGroups`, `LocalModifierOptions`; producto tiene `modifierGroupIdsJson` | `modifier_groups`, `modifier_options`, `product_modifier_groups` (001) | editor de producto, selector POS, sync |
| Inventario de productos | `LocalInventoryStock`, `LocalInventoryMovements` | `inventory_stock`, `inventory_movements` (005–006, cambios posteriores) | ventas, compras, recetas, anulaciones, reportes |
| Inventario de empaques | `LocalPackagingStock`, `LocalPackagingMovements` | `packaging_stock`, `packaging_movements` (009) | compra de empaque, venta, anulación y sync |
| Recetas | sin tabla equivalente examinada en Drift POS en esta revisión | `product_recipes`, `product_recipe_lines` (050), explosión (051/059) y reversión (052) | `component_product_id → public.products.id` |
| Ventas | `LocalSales`, `LocalSaleItems`, `LocalSaleVoids` | `sales`, `sale_items`, `sale_voids` (001, 009 y posteriores) | cierre, anulaciones, historial, costos, cola |

**Evidencia:** `lib/core/database/app_database.dart` (tablas registradas, schemaVersion=34), `tables/catalog_tables.dart`, `tables/inventory_tables.dart`, `tables/sales_tables.dart`, `supabase/migrations/001_initial_schema.sql`, `009_sales_types_packaging.sql`, `050_product_recipes_foundation.sql`. El inventario representa el **esquema declarado**, no la estructura probada del servidor operativo.

## 2. Matriz de dependencias críticas

| Operación | Ruta verificable | Consecuencia al unificar |
|---|---|---|
| Crear/cobrar venta local | `lib/features/sales/data/datasources/local_sales_datasource.dart`: `saveSale` y transacción local; invoca `applySaleMovements` de empaque | La escritura del movimiento debe continuar **atómica** con la venta |
| Anular venta | mismo datasource: `voidSale` invoca reversión de stock normal y de empaques | Revertir del **movimiento original**; no reinterpretar reglas actuales |
| Validar stock de empaque | `lib/features/packaging/data/datasources/local_packaging_movements_part.dart`; `PackagingStockException` | Nunca omitir validación ni permitir doble rebaja |
| Encolar sync | `lib/features/sales/data/repositories/sales_repository_sync_support.dart` serializa `inventoryMovements` y `packagingMovements` por separado | Payloads antiguos deben permanecer legibles; versionar nuevo contrato |
| Enviar venta | `lib/features/sync/data/datasources/supabase_sync_remote_sender_sales_part.dart`; RPC `pos_sync_sale` en ruta de dispositivo | Auditar todas las variantes de RPC y compatibilidad offline |
| Descargar catálogo | `supabase_catalog_pull_service_catalog_part.dart`, `supabase_catalog_pull_service_inventory_part.dart` | Evitar reasignar IDs, perder grupos, o alterar deltas locales pendientes |
| Reconciliar saldo de empaque | `supabase_catalog_pull_service_inventory_part.dart`: `_pendingPackagingDeltasByItem` | Conservar pendientes al cruzar cambio de versión para no sobrescribir stock |
| Inventario remoto por receta | `supabase/migrations/051_recipe_inventory_explosion.sql`, `059_recipe_decimal_inventory.sql` | Motor actual consume productos como componentes; definir exclusión de consumo duplicado |
| Reversión por receta | `supabase/migrations/052_recipe_inventory_void_reversal.sql` | Conservar IDs originales, costo y reversión idempotente |
| Administración de catálogo | `lib/features/admin_remote/data/repositories/supabase_admin_repository_packaging_part.dart` | UI y contratos remotos cambian, con permisos y RLS a preservar |

### Advertencias específicas
1. El POS modela **tipo de venta por orden** (`Documentation/PACKAGING_BY_SALES_TYPE.md`); cambiarlo a nivel de línea sería otra iniciativa.
2. La migración 009 declara `packaging_stock.quantity_on_hand integer` y `packaging_movements.quantity_delta integer`. En contraste, 059 transforma inventario de productos a `numeric(18,6)`; necesitaríamos política de unidades y precisión unificada sin redondeos.
3. `LocalProducts` y `LocalPackagingItems` son tablas distintas, al igual que sus stocks y movimientos; un mero cambio de navegación no las consolida.
4. `supabase_catalog_pull_service_test.dart` contiene prueba `does not store raw materials from device catalog pull`. **Bloqueo de diseño**: un maestro de artículos no significa descargar todo a cada POS. Deben definirse proyecciones selectivas por necesidad operacional.
5. Los modificadores se representan como **opciones y grupos**; convertir indiscriminadamente «sin ingrediente» en artículo inventariable es incorrecto. Vinculación opcional a artículo consumible.

## 3. Contratos de datos que NO deben romperse

- IDs estables `restaurant_id`, `products.id`, `packaging_items.id` y referencias de `product_packaging_rules`; preservar también su historial de ventas/stock.
- Payload de ventas con `sale`, `items`, `inventoryMovements`, `packagingMovements`, y anulación `void`. Se observan en `sales_repository_sync_support.dart` y `supabase_sync_remote_sender_sales_part.dart`.
- Claves de movimientos de empaque de formato `packaging-sale-<saleId>-<itemId>` en `local_packaging_movements_part.dart`; el historial y la idempotencia pueden depender de ellas.
- `pos_sync_sale(uuid, uuid, text, jsonb)` fue envuelto/renombrado en las migraciones 028, 051 y 052; auditar la **definición efectiva final** antes de tocar el RPC.
- RLS y aislamiento por restaurante; política y permisos se ven en 009. Validar alcance de todos los futuros FK y RPC con `restaurant_id`.

## 4. Cobertura automatizada existente (en código, NO ejecutada)

| Evidencia | Casos relevantes |
|---|---|
| `test/features/sales/data/repositories/sales_repository_test.dart` | rebaja empaque Go, no rebaja Aquí, bloqueo por stock insuficiente, reversión de empaque al anular; también stock de productos |
| `test/features/sync/data/datasources/supabase_catalog_pull_service_test.dart` | restauración de datos POS, preservación disponibilidad de modificadores, exclusión de materia prima en pull |
| `test/features/sync/data/datasources/supabase_sync_remote_sender_test.dart` | envío RPC de ventas, cambios de asignaciones de modificadores |
| `test/core/database/app_database_test.dart` | creación y migraciones parciales; **no se verificó** cobertura específica para futura migración de empaques |
| `test/features/recipes/data/services/supabase_product_recipes_service_test.dart` | contrato de recetas administradas |
| `test/features/inventory/data/repositories/inventory_repository_test.dart` | inventario local |

**Gaps exigidos para nueva versión:** migrar stock con movimientos históricos, reintentos offline de cliente antiguo, idempotencia de reenvío, dos versiones de POS simultáneas, anulaciones antes/después de cutover, costo histórico, compras en tránsito, saldos por restaurante/sucursal, RLS negativa cross-tenant, precisión decimal, backup/restore y upgrade Drift desde versiones anteriores. Probar además `flutter analyze`, todas las suites relevantes y compilaciones web/Android aprobadas.

## 5. Diseño de transición propuesto (NO ejecutado)

**Fase 0 — datos y línea base (solo lectura).** Comprobar esquema realmente aplicado, número de registros y referencias, saldos, movimientos sin referencia, colas POS pendientes, versiones de dispositivos, permisos, RLS, índices/únicos/triggers/RPC. Hacer export/backup restaurable y registrar checksums y conteos. No descargar datos sensibles al documento público.

**Fase 1 — expand compatible.** Añadir clasificación y atributos del artículo al maestro sin borrar estructuras viejas; tabla de mapeo `legacy_packaging_id → unified_item_id` con unicidad por restaurante; mantener APIs y payloads viejos. Diseñar tipos de artículo **separados** de capacidades como vendible/control de stock/consumo de receta. Decidir si conviene preservar UUID original donde sea posible.

**Fase 2 — migración controlada.** Backfill repetible de empaques con unidades/costos, mapping; reconciliar a fecha de corte saldos/movimientos históricos sin duplicarlos. Probar en copia aislada con hashes y balances antes/después. **Prohibido** restar ambos orígenes o reconstruir histórico desde reglas actuales.

**Fase 3 — coexistencia.** Introducir lectura compatible y payload versionado; un **solo escritor/autoridad de stock por tipo de evento**. Registrar versión mínima de POS/ventanas de compatibilidad, manejar colas anteriores al cambio y compensación por reintentos. Criterios de salida de clientes legacy.

**Fase 4 — cutover reversible.** Feature flag por restaurante tras reconciliación y QA; observabilidad de diferencias y bloqueos; cambio de lectura/escritura con rollback documentado. No publicar sin ventana operativa y aprobación específica.

**Fase 5 — limpieza posterior.** Solo cuando no queden clientes antiguos, movimientos no reconciliados o usos de tablas legacy; archivar evidencia; deprecar, **no borrar de inmediato**. Mantener reporte histórico.

### Rollback mínimo
Revertir feature flag/lecturas al contrato anterior mientras aún se soporta; suspender migraciones de escritura nuevas si hay divergencia; no ejecutar `DROP` sobre tablas originales; preservar mapping y movimientos. Si se produjo escritura irreversible, requerir procedimiento de reconciliación documentado desde backup en entorno aislado, antes de cualquier rollback.

## 6. Criterios para autorizar implementación
1. Esquema de producción real, data profiling y estado de todos los POS verificados.
2. Contrato de artículo unificado y decisión sobre tipos de venta/modificadores/servicios aprobados.
3. Matriz FK/RPC/consumidores exhaustiva (incluye SQL dinámico), modelo de costos y unidades.
4. Migración replay-safe con checks de igualdad de stock y movimiento, y rollback probado.
5. Tests automatizados y de integración para los casos listados; prueba de RLS.
6. Firma de seguridad funcional: no se altera el comportamiento de venta, anulación o sync.
7. Aprobación expresa para cambios de esquema, código, despliegue y ventana.

## 7. Estado y límites reales
Esta auditoría cubrió las **familias principales** de dependencias en código y migraciones, pero **NO es una certificación exhaustiva de todas las referencias y triggers** ni de la producción. No se leyeron completamente todos los archivos SQL de las 81 migraciones ni se ejecutó análisis automático integral de usos. La siguiente etapa de auditoría antes de implementar debe producir inventario completo generado de referencias y confirmar la definición remota final de RPC/FK y datos reales. Sin acceso autorizado a producción, esa etapa seguirá abierta.

**Resultado:** modelo unificado arquitectónicamente razonable; **NO APTO PARA MIGRACIÓN INMEDIATA**. Prioridad crítica: consistencia e idempotencia histórica/offline.

**Bitácora:** documento solo lectura de la aplicación. No cambia código, SQL, datos ni despliegues.
