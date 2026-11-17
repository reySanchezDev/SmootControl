# Matriz de dependencias para limpieza

| Objeto legado | Referencias observadas | Acción segura |
|---|---|---|
| `public.products` | Pull Flutter, funciones POS, inventario y datos históricos | Migrar consumidores; no borrar todavía |
| `sale_items.product_id` | Venta, reportes, sincronización, anulación | Introducir `item_id` y conservar histórico hasta migración |
| `product_modifier_groups` | Catálogo POS y modificadores | Migrar a relación de item |
| `product_recipe_lines` / `product_recipes` | Recetas e inventario | Migrar a relación de item |
| `product_packaging_rules` | Empaques y venta | Migrar a relación de item |
| `pos_sync_sale` y wrappers | Cola de ventas, stock, anulaciones | Sustituir por contrato canónico y retirar al final |

## Preflight obligatorio antes de borrar

1. `rg` sin referencias ejecutables en Flutter y migraciones futuras.
2. Consultas a `pg_depend`, `information_schema` y cuerpos de funciones sin
   referencias al objeto.
3. Conteos históricos conciliados y respaldados.
4. Pruebas E2E verdes en Docker local.
5. Migración de retiro revisada y aplicada primero en una copia restaurable.

