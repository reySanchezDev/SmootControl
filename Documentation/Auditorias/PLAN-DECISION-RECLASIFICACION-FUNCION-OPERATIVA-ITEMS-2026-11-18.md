# Decisión y plan: función operativa mutable de artículos

**Fecha:** 2026-11-18  
**Estado:** decisión de arquitectura adoptada; implementación de reclasificación bloqueada hasta cerrar compatibilidad POS offline.  
**Entorno:** exclusivamente Supabase Docker local y worktree `feature/item-core-end-to-end-implementation`.  
**Límite:** no se modificaron `main`, Supabase remoto, producción ni la migración 088.

## Decisión para SmooControl

La función operativa (`items.item_class`: Producto de venta, Materia prima o Empaque) debe poder cambiar durante la vida del artículo sin cambiar `items.id`, código comercial, procedencia técnica ni historial. No se habilitará como una edición ordinaria ni como un simple cambio de dropdown: será una **reclasificación explícita, auditada y transaccional**.

Se mantienen separadas estas responsabilidades:

| Dato | Decisión | Regla |
|---|---|---|
| `items.id`, `commercial_code` | Identidad inmutable | La reclasificación conserva ambos valores y todas las FK históricas. |
| `item_class` | Función operativa modificable | Solo por un RPC dedicado, con actor, motivo, valores anterior/nuevo y timestamp auditados. |
| `item_type` | Tratamiento de inventario independiente | No cambia al reclasificar. `tracks_inventory` sigue derivado de `item_type`; cambiar `item_type` es otra operación y requiere sus propias precondiciones de saldo e historial. |
| `source_kind`, `source_id` | Procedencia técnica inmutable durante la transición | No se reescriben para simular una conversión. Dejan de determinar la función operativa una vez migrados todos sus consumidores. |
| Ledger y saldo | Historia original | No se borran, copian, renombran ni recalculan movimientos anteriores. La venta/anulación usa el snapshot de la transacción original. |
| Capacidades comerciales | No se conceden implícitamente | Reclasificar no activa venta, compra, visibilidad POS, receta ni cocina. El usuario confirma capacidades compatibles en la misma operación; el servidor aplica las restricciones de cada clase. |

Una fila heredada en `packaging_items` no se eliminará para poder convertirla. La tabla se conserva como compatibilidad/procedencia hasta retirar formalmente todos sus lectores y escritores. El trigger heredado no podrá volver a imponer la clase anterior; el escritor de legado se actualizará para preservar el `item_class` canónico.

## Fundamento y límite de seguridad

La migración 121 rechaza hoy cambios de clase. La restricción de 088 liga clases con `source_kind`; la sincronización heredada puede volver a derivar clase desde `products`/`packaging_items`; y los puentes POS 102/123 enrutan ventas y empaques por origen. Por ello, soltar solo la restricción o habilitar el campo en UI dejaría consumidores con interpretaciones distintas.

En el Docker local se encontraron **48 filas `pos_devices.is_active=true`**, cero ventas remotas con `sync_status` pendiente/error/en progreso, pero el servidor no expone una confirmación comprobable de qué revisión del catálogo sincronizó cada dispositivo. Tampoco se puede observar desde Supabase una cola Drift offline que aún no se haya enviado. El conteo de dispositivos activos no demuestra que estén conectados; sí demuestra que no existe evidencia suficiente para afirmar que todos usan el contrato nuevo. **Por tanto, la reclasificación queda bloqueada hasta que el POS tenga versionado/confirmación de revisión y el servidor pueda rechazar escrituras de clientes incompatibles.**

### Caso crítico: venta enviada con catálogo anterior

Hoy el snapshot de catálogo tiene `revision`/`snapshot_id` y el cliente evita aplicar snapshots obsoletos, pero el payload de `pos_sync_sale_v2` no incluye esa revisión ni una fotografía de `item_class`, `item_type` y reglas/receta usadas al vender. El RPC puede por tanto recibir una venta generada con el catálogo anterior y evaluarla contra el estado actual. En el caso de Empaque, el puente 123 decide compatibilidad por la presencia de una fila en `packaging_items` y por `source_kind`, no por una versión de función vigente al momento de venta.

**Regla decidida:** ninguna conversión puede crear una ventana donde la misma venta sea interpretada de dos maneras. La arquitectura objetivo conservará versiones efectivas del catálogo/reglas necesarias para validar y aplicar operaciones offline, y cada venta enviará la revisión más la identidad de la operación original. El servidor debe validar esa versión y procesar con la semántica correspondiente al momento de venta, o rechazar la operación completa con error recuperable y sin escribir venta/movimientos. El POS debe conservar la venta en su cola y ofrecer reintento/resolución; nunca descartarla ni recalcular automáticamente receta/empaque con la configuración nueva. Una revisión del cliente por sí sola no es suficiente si el servidor ya no conserva el contrato histórico.

Las anulaciones siempre referencian y revierten los movimientos originales, independientemente de la función vigente. No se autoriza usar `item_class` actual para reconstruir los efectos de una venta histórica.

El artículo comercial 4 (`VASO 16ONZ QA`) tiene `item_class=packaging`, `source_kind=packaging`, `item_type=inventory`, saldo local 0 y 0 movimientos en ambas vistas de ledger; no tiene receta ni regla de consumo entrante según las consultas ejecutadas. Sigue teniendo la fila heredada en `packaging_items`, lo cual confirma el acoplamiento de compatibilidad. Es buen caso de prueba después de implementar el version gate, no autorización para convertirlo ahora.

El artículo comercial 10 (`MARUCHAN`) se comprobó como Producto de venta inventariable con saldo 5 y cinco movimientos. Se reserva para verificar edición sin conversión, venta, descuento y anulación exacta en la fase E; no se cambiará su saldo en datos persistentes durante esta auditoría.

## Contrato de transición por clase

| Transición | Regla de negocio propuesta |
|---|---|
| Producto ↔ Materia prima | Conservar `item_type`, saldo e historial. Validar ventas/recetas abiertas y pendientes; no habilitar venta directa al entrar en Materia prima. Los vínculos de receta se conservan si el artículo sigue siendo componente válido; de lo contrario, bloquear con referencias identificadas, nunca borrarlas. |
| Producto ↔ Empaque | Conservar identidad, `item_type` y ledger. Bloquear hasta que reglas de consumo, movimientos, snapshots y anulaciones operen por `item_class` canónico y el version gate POS esté activo. No crear una segunda fila en `packaging_items`. |
| Materia prima ↔ Empaque | Conservar saldo/historial; validar reglas entrantes, receta, negativos permitidos y compatibilidad de unidad. Rechazar si no hay una interpretación inequívoca de dependencias activas. |
| Cualquier clase ↔ Servicio | No es una reclasificación de clase normal: servicio requiere `item_type=service`, sin inventario ni receta. Requiere el procedimiento separado de cambio de tipo y sus validaciones de movimientos/saldo. |

Los saldos distintos de cero no bloquean por sí solos un cambio entre clases físicas que mantienen `item_type=inventory`; el inventario sigue siendo el mismo artículo. Sí se bloquea cualquier combinación cuya semántica de movimientos/dependencias no esté soportada o cuyo POS no haya reconocido el catálogo. Un cambio de `item_type` no se infiere de esta regla.

## Plan medible

| Fase | Trabajo | Criterio de salida | Estado |
|---|---|---|---|
| A. Contrato | Registrar dimensiones, invariantes, transiciones, capacidades, auditoría e historial | Sin contradicciones entre SQL, UI, POS y documentación | **Completada:** este documento fija la decisión y la matriz inicial. |
| B. Inventario de consumidores | Buscar todo uso de `source_kind`, `source_id`, `packaging_items`, clase en ventas, recetas, compras, movimientos, reversas, reportes y sync | Matriz consumidor → contrato nuevo; 0 consumidores sin dueño | **Completada como auditoría inicial:** ver matriz de consumidores debajo. Se confirma que no es seguro retirar aún compatibilidad de empaques. |
| C. Contrato POS offline | Añadir revisión/schema del catálogo por dispositivo, acknowledgment en sync y rechazo server-side de payload incompatible; definir dispositivos que no vuelven a conectarse | Pruebas con cliente anterior rechazado, cliente actualizado aceptado, dispositivo offline y cola pendiente | **Parcial, solo Docker local:** migraciones 129–130 agregan ack V3, revisión en venta, rechazo atómico de revisión obsoleta y barrera DB ante cambio de `item_class` con POS activo sin ack actual. Cliente guarda revisión al encolar, confirma después de aplicar el snapshot y no usa la ruta REST para ventas versionadas. La conversión sigue bloqueada. Falta el flujo de resolución/reconciliación de una venta obsoleta: se conserva como `error` en la cola, pero no puede reintentarse con éxito hasta una resolución explícita. |
| D. Persistencia canónica | Migración posterior a 128: auditoría de reclasificación, RPC dedicado, locking, permiso real, tenant, preflight de dependencias y actualización del espejo heredado sin alterar procedencia | Matriz JWT/RLS/tenant, atomicidad, rollback, concurrencia e idempotencia aprobada; migración 088 intacta | **Pendiente; no aplicada.** |
| E. Consumidores | Cambiar lectores/escritores para que la operación actual use `item_class`; preservar origen únicamente como compatibilidad; adaptar compras, reglas, recetas, venta, anulación, inventario, movimientos y reportes | Auditoría estática sin decisiones operativas derivadas solo de `source_kind`; E2E por clase y por transición | **Pendiente.** |
| F. Backoffice | Habilitar acción “Cambiar función operativa” con impacto, dependencias, motivo obligatorio, confirmación y resultado tipificado; no conceder capacidades silenciosamente | Widget tests, permisos, errores por dependencia, confirmación y persistencia/F5 | **Pendiente; campo continúa protegido.** |
| G. QA local completa | Crear fixtures nuevos y usar 4, 10 y artículos existentes; compra/ajuste/receta/regla/venta POS/anulación/sync/reportes; testear cambios de clase antes/después de operaciones | 100% de casos de transición aprobados; saldo y ledger reconciliados; prueba rollback/tenant/version-gate verde | **Parcial:** flujos base existentes probados abajo; transiciones no ejecutadas por bloqueo de Fase C. |
| H. Release y promoción | Formato/análisis/tests, RELEASE local, QA visual y revisión humana; luego decisión separada para cualquier despliegue | Evidencia local reproducible y autorización explícita para promover | **No iniciada.** |

## Evidencia de pruebas locales ejecutadas

## Auditoría inicial de consumidores (Fase B)

El barrido estático se hizo sobre `lib/` y las migraciones activas de referencia; nombres que aparezcan solo en migraciones antiguas o pruebas históricas no se consideran por sí solos consumidores desplegados. Estos son los consumidores vivos confirmados:

| Área | Consumidor comprobado | Consecuencia / trabajo requerido |
|---|---|---|
| POS: descarga canónica | `pos_pull_item_catalog_v2` (migración 122) publica `item_class`, stock, reglas y `revision`; el cliente aplica `ItemCatalogSnapshotV2`. | Base adecuada para versionar, pero la revisión aplicada no se adjunta a la venta y no hay acknowledgment por dispositivo visible en este contrato. |
| POS: envío de venta | `_pushSaleWithDevice` y `pos_sync_sale_v2` envían líneas y movimientos, sin `catalog_revision` ni `contract_version` del snapshot. | Una venta de cola offline puede llegar después de un cambio y el servidor la procesa con el estado/puentes actuales; el cliente no tiene garantía de semántica histórica ni rechazo por versión. |
| POS: catálogo de compatibilidad | `SupabaseCatalogPullService` todavía descarga `packaging_items`, `packaging_stock` y sales types al refrescar el scope de productos/empaques; existe fallback de lectura de artículos desde `items` cuando no hay snapshot canónico. | Retirar el espejo exige migrar scopes, almacenamiento Drift, escritor/lector y consumidores del catálogo; borrar solo la tabla rompería descarga o instalaciones/compatibilidad legacy. |
| Sync de empaques | `SupabaseSyncRemoteSender` enruta entidad `packaging_items` al upsert heredado; `PackagingRepository` aún encola esa entidad. | Hay ruta de escritura viva desde cliente. Debe cerrarse/migrarse con estrategia de versiones de cliente y colas pendientes antes del retiro de la tabla. |
| Backoffice empaques | `SupabaseAdminRepositoryPackagingPart` mantiene lectura/upsert de `packaging_items`; `PackagingRepository` además conserva modelo y operaciones legacy, aunque la compra administrativa está marcada deprecated. | No es un objeto muerto; algunos usos ya son compatibilidad/solo lectura, otros escriben. La fuente canónica de nuevas reglas ya es `items` + `item_consumption_rules`, pero la retirada debe ser por etapas. |
| Venta/empaque SQL | Migraciones 102 y 123 usan `source_kind='packaging'`; 123 selecciona entre ledger canónico y legacy por existencia de fila `packaging_items`. | El origen técnico todavía decide semántica de movimiento. Debe reemplazarse por clase/capacidades versionadas antes de habilitar reclasificación. |
| Reglas de consumo | Migración 109 sincroniza/consulta empaques legacy; cliente actual también usa `item_consumption_rules` para reglas canónicas. | Hay doble ruta de datos. Requiere reconciliar y hacer explícita la autoridad canónica, sin romper reglas existentes ni reversas. |
| Inventario/reportes/recetas | Servicios actuales filtran por `tracks_inventory` y `item_class` (materia prima); el snapshot y la entidad canónica parsean clase. | Consumidores operativos parcialmente canónicos; cada escritor de movimientos y anulación debe verificarse para no inferir clase solo del artículo actual. |

**Conclusión de Fase B:** se encontraron consumidores activos con dueño; no existe todavía un consumidor `source_kind`/`packaging_items` sin localizar, pero sí hay varias rutas vivas que impiden declarar la compatibilidad retirada. La transición a Fase C debe primero definir un envelope versionado de operación de venta que conserve la semántica de la cola, y una política explícita de drenaje/rechazo de dispositivos viejos. No se habilita reclasificación ni se elimina ninguna tabla en este cambio.

### Avance de la barrera de seguridad POS (18-11-2026)

Las migraciones locales `129_pos_catalog_revision_sale_guard.sql` y `130_pos_catalog_ack_enforced_for_item_reclassification.sql` están aplicadas únicamente al Supabase Docker de esta rama. El snapshot anuncia contrato 3; el POS lo confirma solo después de aplicar transaccionalmente el snapshot. Una venta nueva encola `item_catalog_revision`, `item_catalog_snapshot_id` y versión 3; el servidor exige coincidencia exacta con el catálogo actual y los persiste en la venta. Si llega una revisión anterior, el RPC aborta toda la operación antes de insertar venta o movimientos. Si un dispositivo ya confirmó V3 pero intenta enviar una venta sin identidad de catálogo, el servidor también la rechaza. La cola local conserva el payload y registra error; no se reescribe ni se descarta.

La barrera de reclasificación a nivel DB rechaza cualquier cambio de `item_class` mientras exista un POS activo que no haya confirmado el snapshot/revisión actuales. Esto es intencionalmente fail-closed. **No es aún un mecanismo de recuperación:** una venta offline de revisión antigua queda protegida contra contabilización incorrecta, pero requiere una acción de conciliación diseñada; sincronizar el catálogo y reintentar sin cambiar la operación volverá a ser rechazado. No debe habilitarse la reclasificación operativa hasta entregar esa resolución y probarla.

**Pruebas posteriores a 129–130 (Docker local):** `item_role_maruchan_pos_sale_rollback.sql` pasó ack V3, rechazo de revisión obsoleta sin persistencia, persistencia de revisión en venta, venta actual de MARUCHAN (stock 5→4), y barrera con segundo dispositivo activo sin ack; `local_item_e2e_transaction.sql` pasó nuevamente (3 movimientos y reversión completa de fixture). Ambas transacciones terminan en `ROLLBACK`. Flutter: `flutter analyze` vía Dart MCP sin errores; 37 pruebas dirigidas de snapshot, sender, aplicación offline y catálogo de artículos pasaron.

Supabase Docker estaba arriba; `supabase migration list --local` mostró las migraciones locales 001–128 aplicadas. Las pruebas se ejecutaron dentro del contenedor PostgreSQL con `ON_ERROR_STOP`; cada script termina con `ROLLBACK`, por lo que los productos, la venta y movimientos de prueba no quedan como datos de operación.

| Prueba | Resultado observado |
|---|---|
| `supabase/tests/local_item_e2e_transaction.sql` | **PASS.** Crea y edita un artículo mediante `app_upsert_item_v2`; confirma código generado `ART-n`; crea receta y regla de empaque; registra compra; sincroniza venta por `pos_sync_sale_v2`; observa 3 movimientos ligados a venta; valida descuento del artículo, materia prima y empaque; ejecuta ajuste de entrada/salida y consulta el reporte. Transacción revertida. |
| `supabase/tests/item_type_stock_authority_local.sql` | **PASS.** Tipo inventariable deriva stock; códigos estables; Servicio sin stock/receta; downgrade con saldo y reclasificación genérica rechazados; RPC interno no ejecutable por cliente. Transacción revertida. |
| `supabase/tests/canonical_inventory_packaging_purchase_adjustment.sql` | **PASS.** Compra y ajuste del empaque actualizan saldo y ledger canónico. Transacción revertida. |
| `supabase/tests/canonical_recipe_negative_stock_rule.sql` | **PASS.** Regla de negativos limitada a materia prima por receta; reversa, atomicidad, reintento idempotente y rechazo para Producto/Empaque. Transacción revertida. |
| `supabase/tests/item_role_maruchan_pos_sale_rollback.sql` | **PASS.** Venta real de prueba por `pos_sync_sale_v2` para el artículo existente 10; detalle de venta y movimiento vinculados al mismo `item_id`; saldo verificado de 5 a 4 dentro de la transacción. `ROLLBACK` dejó saldo 5 y los cinco movimientos originales. |
| Relectura posterior | Artículo 4: saldo 0, 0 movimientos y fila heredada presente. Artículo 10: saldo 5, cinco movimientos. No se observó cambio persistente atribuible a estas pruebas. |
| `flutter analyze` por Dart MCP | **PASS:** sin errores. |
| Pruebas Flutter dirigidas | **PASS:** catálogo de artículos, aplicación del snapshot (incluida conservación de ventas pendientes), editor inline, entidad canónica, parser de snapshot y proyector POS: 6 archivos de prueba aprobados. Se corrigieron fixtures de test que no seguían el endpoint canónico ni enviaban `tracks_inventory`; no se alteró lógica de producción. Archivos Dart formateados con Dart MCP. |

El CLI `supabase db query --file` rechazó el archivo de varias sentencias antes de ejecutarlo (`cannot insert multiple commands into a prepared statement`). La suite se volvió a ejecutar correctamente con `psql` en el contenedor local; no se modificó ningún servicio remoto.

Durante la primera corrida aparecieron también warnings de Drift por varias instancias de `AppDatabase` en una prueba de replay; no falló y queda como oportunidad de mantenimiento del test harness.

## Siguiente paso de implementación

Completar Fase C diseñando una conciliación auditable y recuperable para ventas de revisión antigua (sin relabel silencioso ni cálculo con reglas nuevas), incluyendo cola offline pre-V3 y dispositivos sustituidos. No probar la conversión de `VASO 16ONZ QA` mientras no exista recuperación y todos los POS activos confirmen la revisión. Después, ejecutar la matriz de transición en una transacción de QA y comprobar identidad, código, saldo, ledger, venta/anulación offline antigua y rollback.

**Oportunidad adicional:** la columna `source_kind` hoy mezcla procedencia y enrutamiento operativo. La meta a largo plazo es renombrar/documentar explícitamente su semántica como origen histórico e impedir que nuevas reglas de negocio dependan de ella; solo retirar los puentes y tablas heredadas cuando la auditoría demuestre cero consumidores activos y haya una política de compatibilidad de dispositivos.
