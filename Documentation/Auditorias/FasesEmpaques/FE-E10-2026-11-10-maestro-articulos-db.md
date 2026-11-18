# FE-E10 — Fase 1: fundamento del maestro único de artículos en PostgreSQL

> **AVISO DE ARQUITECTURA (2026-11-10): DOCUMENTO HISTÓRICO / PR #18 CONGELADO.** La migración 088 descrita aquí propone un maestro espejo sincronizado desde tablas legacy. La decisión posterior, tomada tras revisar la auditoría AL/SQL de LS Central, exige **una única autoridad canónica de artículos** y transición verificable del inventario y los demás consumidores. **No ejecutar la 088 ni utilizar este documento como orden operativa.** El único plan vigente, actualizable y con gates es [PLAN RECTOR VIVO — Core de artículos de Kivo](../../Planes/EJECUCION-CODEX-EMPAQUES-END-TO-END.md). Antes de modificar SQL se debe comprobar si 088 ya fue aplicada al laboratorio y cerrar F0/G0 del plan rector.

**Fecha:** 2026-11-10. **Rama:** `feature/item-master-db-foundation`.  
**Estado real:** migración 088, preflight y test SQL **versionados**. **Pendiente de ejecutar en el Supabase local del propietario**; no se ha accedido directamente desde GitHub a su Docker ni se ha alterado producción. No está aprobado para despliegue.

## Decisión de arquitectura

Kivo debe tener **un maestro persistente** `public.items`, como concepto de dominio, que no dependa de cuántas páginas o filtros existan. Separar:

- `item_type`: `inventory`, `non_inventory`, `service`. Semántica de control de stock/valor. Alineado conceptualmente con Business Central, no copia literal del esquema de Microsoft.
- `item_class`: `sale_product`, `raw_material`, `packaging`, `service`. Clasificación comercial, **independiente** del tipo; una bolsa controlada por stock es `inventory + packaging`.
- `is_sellable`, `tracks_inventory`, `is_active`, `unit_cost`, `unit_price`, unidades de base/compra, conversión y categoría como atributos del maestro, sin confundir servicio con stock.
- Identidad, tenant, código estable y procedencia `source_kind/source_id`, índices para código y filtrado, RLS por restaurante.
- Contratos SQL **de lectura** `item_stock_balances` e `item_ledger_entries`: vistas persistidas en el esquema (no duplican registros), combinan saldos/movimientos por `item_id` y mantienen RLS mediante `security_invoker`. Permiten consultar ambos inventarios sin migrar todavía sus ledgers.
- El nuevo tipo Servicio puede registrarse como `source_kind=native`, sin movimientos de inventario ni referencia de producto. **No habilitar venta de servicios desde POS** hasta migrar sus contratos en fase posterior.

### Transición sin pérdida histórica

Las tablas existentes `public.products` y `public.packaging_items` son contratos del POS y de operaciones SQL. Sus claves permanecen, al igual que `inventory_stock/movements`, `packaging_stock/movements`, `sale_items`, recetas, compras, reglas, roles y sincronización.

**La migración 088 no es una vista UNION ni un maquillaje de interfaz.** Crea la tabla física `items`, realiza backfill con el **mismo UUID** de cada fuente y agrega triggers transaccionales de propagación para inserción/edición/borrado en tablas legacy.

**Límite explícito y temporal:** hasta que se migren de manera integral los consumidores POS, compras, recetas y stock, las tablas `products` y `packaging_items` siguen siendo **puntos de escritura autorizados para sus registros**, y el maestro `items` es un catálogo persistido sincronizado. No se permiten actualizaciones arbitrarias directamente sobre artículos de origen legacy. Esto **no** equivale a que el motor POS haya sido unificado. El corte de autoridad definitiva a `items` requiere un contrato de escritura y lectura nuevo, pruebas end-to-end y un rollout sin perder FKs existentes. Está prohibido presentar esta base como eliminación de tablas legacy.

## Auditoría estática del SQL 001–087

| Dominio | Estado observado en migraciones |
|---|---|
| Productos | `products`: UUID, restaurant, category, code, name, price, cost; flags para materia prima, inventario, POS, recetas; unidades de compra/base |
| Empaques | `packaging_items`: UUID, tenant, name, cost, tracks_stock, activo; sin precio de venta ni unidad de medida |
| Stock de productos | `inventory_stock`, `inventory_movements` referencian directamente `products.id` |
| Stock de empaques | `packaging_stock`, `packaging_movements` referencian directamente `packaging_items.id` |
| Consumo de empaque | `product_packaging_rules` relaciona `product_id`, `sales_type_id`, `packaging_item_id`; ahora protegido por RLS/trigger 085–087 |
| Venta y recetas | `sale_items.product_id` y recetas dependen de `products.id` |
| Autorización | RLS en tablas existentes, guardas 085–087; `items` introduce políticas propias, sin relajar las anteriores |
| Servicio | No había entidad de artículo de servicio compartida con venta e inventario; 088 habilita maestro nativo, no operaciones POS aún |

**Auditoría efectiva de registros del Docker local:** `supabase/tests/item_master_preflight_readonly.sql` inspecciona cardinalidad, conflictos de UUID/código, relaciones cross-tenant, integridad de stock y FKs. Debe ejecutarla Codex *antes* de aplicar 088 y reportar sus resultados; GitHub solo contiene el esquema histórico y no verifica datos físicos del contenedor.

## Ficheros de la fase

1. `supabase/tests/item_master_preflight_readonly.sql` — consultas solo lectura, hallazgos y bloqueantes
2. `supabase/migrations/088_item_master_foundation.sql` — tabla persistente, índices, constraints, backfill, triggers, RLS, permisos de servicios nativos y vistas de saldo/movimiento
3. `supabase/tests/item_master_foundation_rollback.sql` — prueba transaccional sintética y `ROLLBACK`; verifica producto, materia prima, empaque, servicio, espejo de actualizaciones, rechazo cross-tenant, identidad y flags

## Barreras de calidad obligatorias

- Verificar **87/87 migraciones** y aislamiento `127.0.0.1:54321/54324`, claves de Kivo Laboratorio, **antes** de intervenir. No `db reset`, no `supabase link`, no service key remota.
- Preflight con **cero bloqueantes**; si existen códigos/productos duplicados o relaciones incoherentes, detener 088 y documentar reparación explícita **solo local** tras revisión de efectos. No borrar datos ni alterar UUID automáticamente.
- Aplicar 088 local mediante migración; contar **88/88**; probar ejecución rollback y CRUD en tablas legacy. Comparar conteos, UUID, nombre, stock, costo, unidad, categoría, clasificación y tenant antes/después.
- Validar **JWT reales** de cuatro perfiles: administrador, solo productos, solo empaques, sin permiso. SELECT de maestro por restaurante; INSERT/UPDATE de servicio nativo solamente con `productos.gestionar`; escrituras sobre filas legacy denegadas; no exponer cross-tenant. El script rollback por sí mismo no prueba HTTP/RLS.
- Actualización de productos/empaques por REST debe sincronizar el maestro **en la misma transacción**, sin afectar movimientos; fallos en restricciones deben revertir escritura legacy.
- Confirmar que `item_stock_balances` e `item_ledger_entries` respetan saldos/movimientos exactamente una vez, tenant, permisos y referencias originales; comparar contra los dos ledgers anteriores sin duplicación. Confirmar relaciones originales de reglas/ventas/stock y operaciones POS anteriores sin regresiones; si aparece incompatibilidad SQL, corregir en la misma rama mediante migración incremental (089 si 088 ya se aplicó localmente), nunca reescribir migraciones aplicadas.
- No iniciar implementación de interfaz: **Fase 2 es exclusivamente posterior** a aprobación de integridad de base; no hacer cambios de Flutter/UX/navegación en este PR.
- Inspeccionar privilegios de `SECURITY DEFINER` y otros triggers en el schema real; validar que ningún usuario cliente pueda manipular `items` cambiando IDs, tenant o procedencia.
- No confundir compilación del Flutter actual con aprobación de la fase DB. QA SQL, HTTP y de contratos prevalecen.
- Documentar comandos, resultados numéricos, versiones y bloqueos reales en este archivo. No afirmar que se aplicó 088 hasta ver evidencia Docker.

## Referencia oficial

Microsoft Learn, *Acerca de los tipos de productos*: https://learn.microsoft.com/es-es/dynamics365/business-central/inventory-about-item-types

La referencia describe Inventario / No inventariado / Servicio y las limitaciones de valoración y control de existencias. Kivo mantiene sus propias clasificaciones funcionales y controles multiempresa.

## Estado de cierre

**G-E10: NO aprobado aún.** La base física, scripts y documentación están en GitHub; falta revisión y ejecución en el laboratorio por Codex. Producción y `main` no han sido modificados.
