# Auditoría: tipo, clase y control de existencias en Artículos

**Fecha:** 2026-11-18  
**Alcance:** diagnóstico de lectura en Docker local y revisión del modelo/formulario canónico. No se modificaron artículos, existencias, esquema ni lógica de negocio.

## Resumen ejecutivo

La ficha mezcla tres dimensiones relacionadas: `item_type`, `item_class` y `tracks_inventory`. `Servicio` aparece como opción tanto de Tipo como de Clase. Además, los datos locales contienen combinaciones donde Tipo y control efectivo de stock no coinciden. El artículo comercial 4 ilustra el problema: es de clase Empaque, pero está configurado sin control de existencias y, por eso, Inventario lo excluye correctamente según su filtro actual.

## Evidencia local

| Código comercial | Nombre | Clase | Tipo | Controla existencias | Activo | Resultado en Inventario |
|---:|---|---|---|---|---|---|
| 4 | VASO 16ONZ QA | `packaging` | `non_inventory` | No | Sí | No aparece; no tiene saldo asociado por `item_id` |

La consulta de Inventario filtra `items` por el restaurante activo, `is_active = true` y `tracks_inventory = true`. El nombre o la clase Empaque no sustituyen ese indicador.

Combinaciones encontradas en el conjunto local inspeccionado:

| Clase | Tipo | `tracks_inventory` | Filas |
|---|---|:---:|---:|
| Empaque | inventory | Sí | 2 |
| Empaque | non_inventory | No | 6 |
| Materia prima | inventory | Sí | 19 |
| Materia prima | non_inventory | No | 1 |
| Producto | inventory | No | 4 |
| Producto | inventory | Sí | 37 |
| Producto | non_inventory | No | 89 |

En la base, `item_type` admite `inventory`, `non_inventory` y `service`; `item_class` admite `sale_product`, `raw_material`, `packaging` y `service`. El formulario ofrece Servicio en ambos selectores y sincroniza parcialmente ambos valores cuando se cambia la clase. La restricción SQL permite `item_type = inventory` con `tracks_inventory = false`, por lo que no garantiza que Tipo signifique control efectivo del saldo.

## Hallazgos y consecuencias

1. **Conceptos acoplados y nombres ambiguos.** Tipo mezcla comportamiento de stock con la naturaleza Servicio; Clase representa la función comercial/operativa. Servicio duplicado hace posible una ficha conceptualmente redundante.
2. **Dos fuentes para control de stock.** `item_type` y `tracks_inventory` no son equivalentes en todas las filas. Inventario usa el segundo como autoridad de inclusión; algunas reglas SQL/POS también consultan ese indicador.
3. **Empaque no implica inventario automáticamente.** `item_class = packaging` clasifica el artículo y habilita su uso en reglas de consumo; `tracks_inventory` determina si mantiene saldo. El artículo 4 está clasificado como empaque no inventariable.
4. **No inferir intención solo desde el nombre/código.** Para el artículo 4 aún debe decidirse si “sin inventario” es intencional o si debe controlar saldo. No se cambió.
5. **Compatibilidad pendiente.** `item_type` está consumido por código, RPC y sincronización. Retirarlo físicamente o cambiar su semántica sin auditar consumidores podría afectar ventas, recetas, POS y datos ya guardados.

## Dirección propuesta para revisión del equipo (no implementada)

- En UX, expresar una sola dimensión de negocio: **Clase** = Producto, Materia prima, Empaque o Servicio.
- Expresar el saldo como **Controla existencias: Sí/No**, disponible solo para clases físicas. Servicio no controla stock y no debe aparecer como segunda opción de tipo.
- Permitir Empaque + Sí/No: un empaque puede tener saldo propio o ser consumible sin seguimiento de stock, según la operación del restaurante.
- Mantener compatibilidad de almacenamiento inicialmente. Antes de consolidar/eliminar `item_type`, definir una matriz de transición para las combinaciones actuales y auditar consumidores SQL, Backoffice, POS offline, snapshots y sincronización.
- Revisar en particular las 4 filas Producto/inventory/no-track y la fila Materia prima/non_inventory/no-track; no convertirlas automáticamente.

## Decisiones que requiere el equipo

1. Confirmar qué significan los campos/tipos equivalentes de “LS” y su mapeo a Clase y Controla existencias; esa equivalencia no quedó identificada en la documentación consultada.
2. Confirmar para el artículo 4 si debe manejar existencias.
3. Aprobar la separación UX propuesta y definir el tratamiento de datos incoherentes antes de cualquier migración.

## Referencias revisadas

- `lib/features/products/domain/entities/canonical_item.dart` — enumeraciones y payload.
- `lib/features/products/presentation/widgets/canonical_item_editor_fields_part.dart` — selectores y acoplamiento de Servicio/Empaque.
- `lib/features/inventory/data/services/supabase_inventory_admin_read_service.dart` — filtro de artículos inventariables.
- `supabase/migrations/121_item_business_class_atomic_write.sql` — validaciones de clase/tipo del escritor.
- `supabase/migrations/107_admin_inventory_item_contract.sql` — contrato de lectura/escritura de Inventario.

## QA RELEASE local relacionado

El RELEASE de QA en `http://127.0.0.1:8103/` se recompiló apuntando al `restaurant_id` real del Docker local. El archivo privado local tenía otro ID; el repositorio conserva su URL y clave privada sin cambios. `bootstrap_status` para el tenant del build devolvió dos perfiles. No se consultó ni modificó Supabase remoto.
