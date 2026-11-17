# Auditoría extensiva de invocaciones legadas

Fecha: 2026-11-17  
Rama: `feature/item-core-end-to-end-implementation`  
SHA auditado: `109f4c66f0500a8486d0a948b67069d914ea2433`

## Alcance y método

Se revisaron, sin modificar código ni datos:

- todas las referencias activas a `products`, `product_id`, `productId`,
  `pos_sync_sale` y `apply_inventory_movement` en Flutter, tests, scripts y
  migraciones;
- rutas de pull, cola de sincronización, POS, ventas e inventario;
- funciones instaladas en PostgreSQL local, permisos, triggers y FK;
- definiciones de las funciones operativas actuales, no solo el texto de las
  migraciones históricas.

## Resultado ejecutivo

La migración canónica todavía no está aislada completamente. La venta nueva usa
`pos_sync_sale_v2` y los movimientos independientes usan
`apply_inventory_movement_v2`, pero existen consumidores activos de las tablas
y contratos legados.

## Invocaciones activas encontradas

### Críticas

1. `SupabaseCatalogPullService` todavía consulta `products` directamente en
   `supabase_catalog_pull_service.dart:173-178`, carga `inventory_stock` por
   `product_id` y aplica `_applyProducts` antes de proyectar el snapshot
   canónico. El pull operativo `pos_pull_operational_catalog` también llama
   internamente a `pos_pull_operational_catalog_legacy_20261117` y después
   agrega `item_catalog_v2`.
2. La cola de sincronización todavía atiende `case 'products'` y
   `_pushProduct`, que escribe `products` y mantiene
   `product_modifier_groups.product_id` en
   `supabase_sync_remote_sender.dart:98` y
   `supabase_sync_remote_sender_admin_part.dart:113-133`.
3. El servicio de inventario administrativo lee `products` y
   `inventory_stock.product_id` en
   `supabase_inventory_admin_read_service.dart:36-74` y escribe payloads con
   `product_id` en `supabase_inventory_admin_write_service.dart:111-158`.
4. El servicio de movimientos administrativos obtiene nombres desde
   `products` y consulta `inventory_adjustment_lines.product_id` e
   `inventory_movements.product_id` en
   `supabase_inventory_movements_service.dart:144-210`.
5. `SupabaseSalesAdminRepository` lee `sale_items.product_id` como campo
   principal, con fallback a `item_id`, en
   `supabase_sales_admin_repository.dart:103-107`.
6. El modelo POS, ventas e inventario continúa nombrando el identificador
   principal `productId` y usa entidades `Product`. Esto no es solo nomenclatura:
   el serializador de ventas envía `item_id` y `product_id` con el mismo valor,
   y la función v2 debe normalizarlo para decidir si es canónico.

### Contratos SQL todavía expuestos

- `public.pos_sync_sale(uuid,uuid,text,jsonb)` continúa instalado y otorgado a
  `anon`, `authenticated` y `service_role`. Su implementación llama al núcleo
  histórico y procesa `product_id`.
- `public.apply_inventory_movement(...)` continúa instalado y otorgado; solo
  valida `products`. Flutter ya usa `apply_inventory_movement_v2`, pero otros
  consumidores aún podrían invocar el RPC antiguo.
- `public.pos_pull_operational_catalog(...)` continúa expuesto y llama
  explícitamente a `pos_pull_operational_catalog_legacy_20261117`.
- Las funciones de recetas, compras, consumo de personal, empaques y ajustes
  todavía usan columnas o argumentos `product_id`.

## Dependencias estructurales instaladas

Persisten FK hacia `products` en:

- `sale_items.product_id`;
- `inventory_stock.product_id`;
- `inventory_movements.product_id`;
- `inventory_adjustment_lines.product_id`;
- `employee_raw_material_consumption_lines.product_id`;
- `product_modifier_groups.product_id`;
- `product_packaging_rules.product_id`;
- `product_recipe_lines.component_product_id`;
- `product_recipes.product_id`.

También existe el trigger `products_sync_item_master`, que sincroniza cambios
desde `products` hacia `items`. Por tanto, `products` sigue siendo una fuente
activa de compatibilidad, no una tabla abandonada.

## Lo que sí quedó canónico

- El pull entrega `item_catalog_v2` y Flutter lo proyecta al read-model POS.
- Las ventas nuevas usan `pos_sync_sale_v2`.
- Las líneas y movimientos canónicos quedan con `item_id` y `product_id` nulo.
- Los movimientos independientes nuevos usan `apply_inventory_movement_v2`.
- Las migraciones 102, 103 y 104 están aplicadas en Docker local.

## Veredicto

No es seguro eliminar todavía `products`, retirar `product_id` ni revocar los
RPC legados. La auditoría demuestra consumidores activos en catálogo, backoffice
de inventario, sincronización administrativa, ventas históricas, recetas,
empaques y consumo de personal.

## Próximo plan obligatorio

1. Migrar el pull de catálogo, stock y dependencias POS a `items/item_id`.
2. Migrar la cola administrativa de productos, recetas, modificadores y
   empaques a contratos `items`.
3. Migrar inventario administrativo, ajustes, compras y reportes.
4. Migrar consumo de personal y explosión de recetas.
5. Añadir un preflight SQL que falle si quedan filas, FK, funciones o clientes
   que dependan de `products/product_id`.
6. Revocar o convertir los RPC legados únicamente después de repetir esta
   auditoría y obtener cero invocaciones activas fuera de compatibilidad
   histórica explícitamente aislada.

## Avance de corrección — fase 1

- Migración 105: el snapshot canónico ahora incluye stock por `item_id`.
- POS local: `CanonicalItemPosProjector` persiste ese stock en Drift y la ruta
  con snapshot canónico ya no consulta ni aplica `products`,
  `product_modifier_groups` o `inventory_stock.product_id`.
- Inventario administrativo: la lectura de stock usa `items` y
  `inventory_stock.item_id`.
- Drift local subió a schema 38 para conservar `quantity_on_hand` del snapshot.
- Verificación: SQL local devolvió 157 artículos y stock 11 para el fixture;
  analyze sin diagnósticos y pruebas dirigidas 30/30 aprobadas.

La auditoría completa aún permanece abierta porque cola administrativa,
escrituras de inventario, ventas administrativas, recetas, empaques y consumo
de personal todavía requieren migración.

## Avance de corrección — fase 2 de lecturas

- Migración 106 añadió `inventory_adjustment_lines.item_id` y backfill de 53
  líneas locales.
- Ventas administrativas leen `sale_items.item_id`.
- Detalle e historial de movimientos leen `item_id` y resuelven nombres desde
  `items`.
- No se alteró todavía la cola administrativa de productos ni sus relaciones de
  modificadores: esa migración queda bloqueada hasta disponer del contrato
  canónico de modificadores, para no perder funcionalidad.

## Avance de corrección - fase 3: escrituras administrativas

- Migración 107 crea `app_register_inventory_purchase_batch_v2` y
  `app_register_inventory_adjustment_batch_v2`; ambos validan `items`, exigen
  permiso administrativo y escriben movimientos con `item_id`.
- `inventory_adjustment_lines.product_id` queda nullable para nuevas líneas;
  el FK histórico se conserva mientras existan consumidores heredados.
- El servicio Flutter de compras y ajustes usa los RPC v2 y envía `item_id`.
- Evidencia local: compra 11→13; ajuste 13→12; ajuste persistido con
  `item_id` y `product_id` nulo; lote inválido hizo rollback completo; otro
  restaurante fue rechazado por autorización. Pruebas dirigidas 4/4 y analyze
  dirigido sin diagnósticos.

La limpieza integral sigue bloqueada hasta migrar modificadores, recetas,
empaques, consumo de personal y los RPC heredados identificados en esta
auditoría.

## Avance de corrección - fase 6: consumo de personal

- Migración 110 añadió `employee_raw_material_consumption_lines.item_id`,
  backfill de 6 líneas y contratos administrativos canónicos para listar,
  guardar y eliminar consumos.
- La prueba local guardó una línea con `item_id`, descontó stock 140→138 y la
  eliminación lo restituyó a 140; el registro y sus movimientos se eliminaron
  dentro de la misma transacción de prueba.
- Migración 111 reemplazó el núcleo POS de consumo de personal para líneas y
  movimientos con `item_id`, manteniendo idempotencia por identificador.
- Analyze dirigido sin diagnósticos y pruebas de staff aprobadas.

El preflight final todavía debe cubrir reportes, sincronizadores históricos y
las dependencias estructurales restantes antes de ejecutar una eliminación.

## Avance de corrección - fases 4 y 5

- Migración 108 copió las recetas compatibles a `item_recipes` e
  `item_recipe_lines` y sustituyó el cálculo de costo, consumo y reversión POS
  por `item_id`. La prueba local transaccional consumió 6 unidades de materia
  prima y la reversión las restituyó; se confirmaron dos movimientos canónicos.
- Migración 109 copió 8 reglas de empaque a `item_consumption_rules` y cambió
  los RPC POS de filtrado de inventario/empaque para resolver por artículos.
- El repositorio administrativo de empaques ya lee y escribe el RPC canónico
  `app_upsert_item_consumption_rule_v2`.

La migración aún no se considera cierre final: quedan consumo de personal,
reportes históricos y algunos contratos administrativos heredados por migrar y
verificar antes de revocar `products`.
## Fase 7 — cierre de consumidores y objetos legacy

- `112_item_modifier_group_contract.sql` creó `item_modifier_groups`, migró 20 asignaciones y el repositorio administrativo dejó de leer/escribir `product_modifier_groups`.
- `113_item_sales_report_contract.sql` llevó costos, desempeño y guardado de recetas al contrato de `items`/`item_recipes`.
- `114_remove_pos_sale_product_compatibility.sql` eliminó del RPC POS la compatibilidad explícita con `public.products`.
- `115_close_legacy_item_consumers.sql` completó backfills nulos, retiró RPCs administrativos sin consumidores y dejó `apply_inventory_movement` como adaptador hacia `apply_inventory_movement_v2`.
- `116_canonical_inventory_movement_rpc.sql` eliminó el fallback de `apply_inventory_movement_v2` a `products`; el movimiento valida y persiste por `item_id`.
- El servicio de recetas, reportes, sincronización POS y repositorio administrativo fueron revisados y llevados a `items`, `item_recipes`, `item_modifier_groups` e `item_consumption_rules`.
- `117_remove_legacy_product_catalog.sql` se aplicó únicamente al Supabase Docker local. Eliminó `products`, `product_modifier_groups`, `product_packaging_rules`, `product_recipes` y `product_recipe_lines`. La consulta posterior no encontró tablas legacy ni funciones activas con referencias a esos objetos.

Evidencia local posterior: la consulta de funciones con `public.products`, `public.product_modifier_groups`, `public.product_packaging_rules` o `public.product_recipes` devolvió cero filas; la consulta de tablas legacy también devolvió cero filas. No se ejecutó migración 088.
