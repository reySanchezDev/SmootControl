# Auditoría E2E Items → POS → Inventario

Fecha: 2026-11-17  
Entorno: worktree QA + Supabase Docker local  
Rama: `feature/item-core-end-to-end-implementation`  
SHA inicial de auditoría: `dc7bbe068797887f0d6303ac46222778f5b35342`

## Objetivo

Verificar el ciclo completo del maestro `items`: creación y edición en
Backoffice, publicación al catálogo POS, venta, movimientos de inventario,
anulación, reintentos e idempotencia. La auditoría también determina si es
seguro retirar tablas y funciones legadas.

## Regla de seguridad

No se eliminan tablas, columnas ni funciones mientras exista una referencia
ejecutable desde Flutter, migraciones aplicables, funciones SQL o datos
históricos. La limpieza se realizará en una migración posterior, con respaldo,
matriz de dependencias vacía y pruebas verdes.

## Estado resumido

| Área | Estado | Evidencia |
|---|---|---|
| Crear/editar `items` | Parcialmente aprobado | `app_upsert_item_v2` crea y actualiza en Docker local |
| Código comercial único | Aprobado en local | Restricción tenant + contador; códigos 201/202 comprobados |
| Categoría del item | Aprobado en local | `category_id` validado contra `product_categories` |
| Descarga canónica POS | Aprobada a nivel SQL | `pos_pull_item_catalog_v2`, contrato 2, snapshot completo |
| Aplicación al catálogo POS Flutter | Bloqueada | Cliente aún solicita `products` y aplica `localProducts` |
| Venta POS de item nuevo | No certificada | Falta contrato POS de venta basado en `item_id` |
| Descarga de inventario | No certificada para item nuevo | Flujo actual usa `product_id`/`products` |
| Anulación y reversión | No certificada para item nuevo | Depende de la ruta legada de ventas |
| Limpieza de objetos legados | No autorizada todavía | Hay dependencias activas |
| Certificación Flutter/RELEASE | Bloqueada por entorno | C: tiene aproximadamente 20 MB libres |

## Documentos

- `01-hallazgos.md`: hallazgos reproducibles, severidad y evidencia.
- `02-plan-medible.md`: fases, criterios de salida y avance.
- `03-matriz-dependencias.md`: objetos y referencias que deben desaparecer o migrar.
- `04-casos-prueba.md`: casos E2E y resultados comprobables.

