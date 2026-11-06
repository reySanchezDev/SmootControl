# AUD-2026-11-06-001 — Auditoría inicial del maestro unificado de artículos

- **Fecha:** 2026-11-06.
- **Estado:** revisión estática inicial realizada; cambios funcionales NO autorizados.
- **Rama de código consultada:** `develop/backoffice-stabilization-integration`.
- **Método:** lectura de código y migraciones versionadas, sin ejecutar código, SQL, tests o despliegues.
- **Alcance:** productos, empaques, modificadores, tipos de venta, recetas, stock, POS y sincronización.
- **Propósito:** evitar repetir auditorías y fundamentar un modelo maestro de artículos consistente, escalable y seguro.

## Hallazgos verificados con archivos

| Hallazgo | Evidencia |
|---|---|
| Producto incluye precio/costo, POS, materia prima, receta, inventario, unidades y grupos de modificadores; no modela el subtipo «empaque» | `lib/features/products/domain/entities/product.dart` |
| Empaques tienen entidad y datasource exclusivos | `lib/features/packaging/domain/entities/packaging_item.dart`; `lib/features/packaging/data/datasources/local_packaging_catalog_part.dart` |
| Tipos de venta son entidades independientes y aplican por orden, no por línea | `lib/features/packaging/domain/entities/sales_type.dart`; `Documentation/PACKAGING_BY_SALES_TYPE.md` |
| Regla de empaque asocia producto, tipo de venta, empaque y cantidad | `lib/features/packaging/domain/entities/product_packaging_rule.dart` |
| Stock y kardex de empaque se separan de inventario de productos, tanto local como remoto | `supabase/migrations/009_sales_types_packaging.sql`; `Documentation/PACKAGING_BY_SALES_TYPE.md` |
| POS valida stock de empaque, genera consumos por venta y movimientos inversos al anular | `lib/features/packaging/data/datasources/local_packaging_movements_part.dart` |
| El identificador de movimiento de consumo depende del ID de venta y de empaque | `local_packaging_movements_part.dart`: formato `packaging-sale-<saleId>-<itemId>` |
| Modificadores son grupos/opciones con diferencial de precio, sin referencia obligatoria a un artículo físico | `lib/features/modifiers/domain/entities/modifier_group.dart`; `modifier_option.dart`; `lib/features/modifiers/data/datasources/local_modifiers_datasource.dart` |
| Recetas ya referencian artículos de `products` como componentes | `supabase/migrations/050_product_recipes_foundation.sql`, `product_recipe_lines.component_product_id` |
| Administrador remoto accede por separado a `sales_types`, `packaging_items` y `product_packaging_rules` | `lib/features/admin_remote/data/repositories/supabase_admin_repository_packaging_part.dart` |

## Evaluación
**Viable como modelo objetivo**, NO viable como simple operación de mover campos o sustituir una pantalla.

- Proponer maestro de artículos compartido para vendibles, materias primas, empaques y servicios; atributos funcionales separados de su clasificación.
- Conservar `sales_types` como dominio operativo y las reglas de consumo como relaciones entre artículos y contextos.
- Los modificadores deben seguir como agrupadores de elección. Solo las opciones con costo/consumo físico requieren vincularse a un artículo; instrucciones como «sin cebolla» no equivalen necesariamente a productos.
- Analizar un kardex de artículos unificado sin perder trazabilidad de los movimientos de empaque existentes.

## Riesgos identificados

| Prioridad | Riesgo | Control requerido |
|---|---|---|
| Crítica | Alterar ID de empaque deja huérfanos movimientos, reglas, stock o ventas offline | Mapeo persistente y migración reversible |
| Crítica | Doble descuento al convivir antiguo y nuevo motor | Idempotencia y corte de consumo único por venta |
| Crítica | Anulaciones recalculadas con reglas nuevas | Revertir el movimiento original, mantener historial |
| Alta | Versiones anteriores del POS sincronizan esquema viejo | Versionado de payloads y compatibilidad progresiva |
| Alta | Reglas y datos entre restaurantes | FKs, alcance por `restaurant_id`, RLS y pruebas de aislamiento |
| Alta | Costos históricos, unidades y decimales | Modelo de unidades, costos históricos y precisión antes del backfill |
| Alta | Cambios de receta/empaque afectan caja y reportes | Pruebas de venta, anulación, compra, inventario, costo y sync |

## Límites y pendientes (NO verificados)
No se inspeccionó exhaustivamente todo Drift, RPCs remotos recientes, ramas de integración, tests, base de producción ni filas reales. No se demostró que todas las migraciones versionadas estén aplicadas. Tampoco se evaluó el estado funcional real de clientes POS antiguos.

## Decisión provisional
**Recomendar un maestro unificado de artículos**, manteniendo reglas, tipos de venta y grupos de modificadores como entidades distintas. No ejecutar migraciones ni refactorizaciones sin completar una matriz de dependencias y un plan de backfill, coexistencia, reversión y pruebas.

## Siguiente auditoría
`AUD-2026-11-06-002`: mapa exhaustivo de SQL/Drift/POS/sync, pruebas, contratos y plan de transición reversible (solo lectura). Evitar repetir esta inspección; contrastar únicamente diferencias de commits y nuevos hallazgos.
