# Caso para análisis: cambiar la función operativa de un artículo

**Fecha:** 2026-11-18
**Estado:** investigación y decisión pendientes; no implementar la conversión hasta aprobar el contrato.
**Alcance:** maestro canónico `items`, Backoffice, inventario, reglas de consumo, recetas, POS y compatibilidad heredada. Solo laboratorio local.

## Solicitud de negocio

La función operativa de un artículo puede cambiar con el tiempo. El usuario necesita poder corregir desde la ficha una clasificación equivocada o reflejar una decisión operativa nueva, por ejemplo pasar un artículo de Empaque a Producto o Materia prima. No debe quedar fijada permanentemente al crear el registro.

La necesidad es cambiar la **función operativa** (`item_class`), no cambiar la identidad del artículo. Deben conservarse el mismo `items.id`, código comercial, historial de movimientos y referencias históricas. El usuario no ha autorizado todavía una conversión irrestricta; pidió detenerse para analizar las protecciones y comparar el diseño con Business Central/LS Central antes de decidir la implementación.

## Modelo actual de SmooControl

- `item_type`: `inventory`, `non_inventory` o `service`; define el tratamiento de existencias. Desde la migración 128, `tracks_inventory` se deriva en el servidor y debe coincidir exactamente con `item_type = inventory`.
- `item_class`: `sale_product`, `raw_material`, `packaging` o `service`; gobierna capacidades operativas y validaciones de venta, receta y consumo.
- `source_kind`/`source_id`: procedencia técnica/compatibilidad de origen (`product`, `packaging`, `native`), actualmente ligada por constraints a algunas clases.
- Identidad estable: `items.id`, `commercial_code` y el historial de `inventory_movements` deben mantenerse al reclasificar.

No asumir que `source_kind` debe cambiar junto con la función operativa. Investigar si debe permanecer como procedencia inmutable mientras `item_class` se vuelve editable, o si debe reemplazarse gradualmente por un modelo de origen/compatibilidad que no condicione el rol operativo.

## Protecciones comprobadas en el estado actual

1. El editor de Productos deja deshabilitado `Función operativa` para artículos existentes; en creación sí se elige.
2. La función activa `app_upsert_item_v2` delega en contratos anteriores; la migración 121 rechaza explícitamente un `item_class` diferente con `item_class_identity_conversion_not_allowed`.
3. `items_class_contract`, originado en la migración 088, exige actualmente `packaging -> source_kind=packaging`, `raw_material -> source_kind=product` y `sale_product -> source_kind=product`.
4. El trigger `items_identity_guard` bloquea cambios a `source_kind` y `source_id`.
5. La fila local del artículo comercial 4, `VASO 16ONZ QA`, es `item_class=packaging`, `item_type=inventory`, `source_kind=packaging`, `can_purchase=true`, `can_sell=false`; existe también una fila con el mismo ID en `packaging_items`. En la inspección realizada no tenía regla de consumo ni receta asociada. Antes de cualquier caso real deben volver a leerse saldo, movimientos y cola pendiente: no se infieren a partir de la captura.
6. El puente POS de la migración 123 enruta movimientos de empaques canónicos usando `source_kind='packaging'`. El flujo heredado todavía tiene la tabla `packaging_items` y un trigger que sincroniza esa fuente con `items`; por tanto no basta con habilitar el selector ni con cambiar solamente `item_class`.

Estas protecciones preservan la coherencia del modelo y los puentes heredados, pero hacen imposible una decisión operativa cambiante desde el flujo ordinario de edición. No concluir que todas deban mantenerse tal cual: evaluar cuál protege identidad/procedencia y cuál está imponiendo indebidamente que el rol sea inmutable.

## Comparación solicitada con Business Central / LS Central

Usar como base documental [la investigación BC/LS Central](REFERENCIA-BUSINESS-CENTRAL-LS-CENTRAL-ARTICULOS-2026-11-18.md) y [la propuesta estructural de SmooControl](PROPUESTA-ARTICULOS-CLASE-STOCK-SMOOCONTROL-2026-11-18.md). La investigación existente distingue `Item.Type` de Business Central (Inventory, Non-Inventory, Service) y `Recipe Item Type` de LS Central (Blank, Ingredient, Recipe); no establece equivalencia uno-a-uno con `item_class` ni una clase nativa universal Empaque.

Investigar y citar fuentes oficiales vigentes para responder expresamente:

- ¿Qué restricciones impone Business Central al cambiar `Item.Type` después de contabilizar movimientos? ¿Qué precondiciones, páginas de error o procedimientos soportados documenta?
- ¿Cómo trata LS Central el cambio de `Recipe Item Type`, BOM/ingredientes y movimientos ya registrados?
- ¿Existe en BC/LS un concepto equivalente a la función operativa empaques de SmooControl, o corresponde a categoría/atributo, ingrediente/componente, BOM adicional o personalización?
- ¿Qué aprendizaje sí aplica a SmooControl y qué sería una falsa equivalencia? Separar hechos de inferencias.

## Opciones de diseño que debe evaluar el análisis

1. **Conversión transaccional controlada:** selector editable; RPC de reclasificación que conserva ID/código/historial, deriva capacidades, revisa referencias y guarda evento auditable con valor anterior/nuevo, usuario, fecha y motivo.
2. **Función independiente de procedencia:** mantener el origen técnico inmutable y dejar de usarlo para inferir clase o seleccionar consumidores; adaptar todos los lectores y escritores relevantes a `item_class`.
3. **Compatibilidad heredada explícita:** decidir qué hacer con `packaging_items` y POS antiguos al salir/entrar de Empaque. No borrar movimientos históricos; considerar archivado/inactivación, proyección compatible o version gate. Evitar que el trigger heredado revierta la reclasificación.
4. **Política sobre dependencias:** definir qué se bloquea, qué se conserva y qué se desactiva al cambiar de clase: saldo, reglas de consumo entrantes/salientes, recetas, compras, permisos, POS, operaciones abiertas y cola de sincronización. No borrar relaciones/historial en silencio.
5. **Migración aditiva posterior:** no editar/reaplicar migración 088 ni reescribir 128 ya aplicada localmente. Si se aprueba, crear una migración posterior con preflight, rollback transaccional, mínimos privilegios y pruebas JWT/tenant.

## Matriz mínima de aceptación propuesta para debate

| Caso | Resultado que debe definir el contrato |
|---|---|
| Cambiar clase sin saldo, movimientos ni dependencias | Conversión permitida y reread muestra nueva función. |
| Cambiar clase con saldo distinto de cero | Definir si se permite conservando saldo e historial o se requiere ajuste/motivo/autorización; nunca descartarlo. |
| Artículo presente en receta o regla de consumo | Bloquear o mantener/inactivar la relación de forma explícita y reversible; no borrarla silenciosamente. |
| Empaque con fila heredada `packaging_items` | Mantener una única identidad y evitar que el trigger/cliente antiguo resucite la clase anterior o genere doble consumo. |
| Transición hacia Empaque | Reglas, compra y consumo posterior operan en el maestro canónico; validar también sincronización offline y unidades. |
| POS offline, cola pendiente u operación abierta | Version gate o rechazo claro; no sincronizar payload con semántica distinta. |
| Reintento, error a mitad de transición o tenant distinto | Atomicidad/idempotencia; rollback completo y autorización/RLS sin cruce de tenant. |
| Venta/anulación posterior a reclasificación | Movimientos nuevos siguen la clase nueva; anulaciones históricas revierten los movimientos originales, no recalculan según la clase actual. |

## Pregunta de análisis para ChatGPT/equipo

> A partir de esta evidencia y de las fuentes oficiales de Business Central y LS Central, propongan un contrato mantenible para que la función operativa de un artículo pueda cambiar sin cambiar su identidad ni corromper historial. Comparen alternativas, separen hechos documentados de inferencias, describan el tratamiento de `item_type`, `item_class`, `source_kind/source_id`, `packaging_items`, saldos, reglas, recetas, POS offline y anulaciones. Recomienden precondiciones por transición, controles de autorización/auditoría, estrategia de compatibilidad y pruebas de aceptación. No propongan habilitar solo el dropdown ni eliminar tablas/datos históricos sin analizar consumidores. No tocar `main`, producción, Supabase remoto ni la migración 088.

## Límites y estado

- Supabase Docker local ya tiene aplicada la migración 128 del trabajo anterior; verificar el estado antes de futuras pruebas.
- No se ha implementado ni aplicado ningún cambio para permitir editar `item_class`.
- La propuesta debe volver al propietario para decidir el contrato antes de crear una migración de reclasificación.
- Documentos relacionados: [revisión arquitectónica y resultados locales](REVISION-PROPUESTA-CLASE-STOCK-ITEMS-2026-11-18.md), [auditoría original](ARTICULOS-TIPO-CLASE-STOCK-2026-11-18.md), [propuesta de clase/stock](PROPUESTA-ARTICULOS-CLASE-STOCK-SMOOCONTROL-2026-11-18.md), [investigación BC/LS](REFERENCIA-BUSINESS-CENTRAL-LS-CENTRAL-ARTICULOS-2026-11-18.md).
