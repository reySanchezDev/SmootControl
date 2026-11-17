# Plan medible de estabilización

## Fase 0 — Línea base y protección (100% documentada)

- [x] Confirmar rama, SHA y laboratorio Docker local.
- [x] Confirmar migraciones 089–100 aplicadas; 088 congelada.
- [x] Registrar referencias activas a `products` y `product_id`.
- [x] Crear esta auditoría y no ejecutar eliminaciones destructivas.

## Fase 1 — Contrato canónico POS (0%)

- [ ] Definir payload versionado con `item_id`, `commercial_code`, snapshot de
  nombre/precio/costo/categoría y unidad.
- [ ] Conectar `pos_pull_item_catalog_v2` al servicio de pull de Flutter.
- [ ] Crear/aplicar tablas Drift canónicas o una capa de compatibilidad aislada,
  sin duplicar reglas de negocio.
- [ ] Criterio: item nuevo visible en POS tras pull y F5, con categoría y precio.

### Evidencia de arranque

La línea base del modelo canónico y del applier está verde. El POS existente
también está verde sobre su contrato legado; esto no se cuenta como avance de
la Fase 1 hasta que el catálogo real consuma `items`.

## Fase 2 — Venta e inventario canónicos (0%)

- [ ] Implementar un RPC versionado de venta con `item_id` y validación tenant,
  permisos, precio, disponibilidad e idempotencia.
- [ ] Migrar el serializador de venta, cola, reintento y anulación al contrato.
- [ ] Aplicar movimientos a `item_stock_balances`/ledger o al modelo vigente
  definido por la migración, con reversión transaccional.
- [ ] Criterio: venta, descarga, consumo, ajuste, anulación y reintento dejan
  exactamente un efecto neto esperado.

## Fase 3 — Migración de dependencias (0%)

- [ ] Migrar recetas, modificadores, empaques y reportes a `item_id`.
- [ ] Vaciar la matriz de dependencias legadas.
- [ ] Crear migración posterior que retire objetos obsoletos, con preflight que
  falle si quedan filas o referencias.
- [ ] Criterio: ninguna consulta Flutter/SQL/migración aplicable depende de las
  tablas retiradas.

## Fase 4 — Certificación (0%)

- [ ] Pruebas SQL de tenant, JWT, permisos, rollback e idempotencia.
- [ ] Pruebas Flutter dirigidas y suite POS/sync.
- [ ] Build Web RELEASE oficial con defines locales.
- [ ] Prueba visual responsive y acta de resultados.

## Regla de avance

Una fase solo se marca completa con evidencia enlazada, pruebas ejecutadas y
resultado reproducible. Los porcentajes anteriores no son estimaciones de
calidad: representan criterios de salida cumplidos.

