# Auditoria Ready For Supabase

## Objetivo

Asegurar que el desarrollo local de SmooControl pueda migrarse al proyecto
remoto Supabase `SmooControl` sin rehacer flujos de negocio.

## Regla General

Todo modulo que persista datos debe quedar alineado con:

- tabla local Drift;
- tabla remota Supabase;
- payload de sincronizacion;
- auditoria funcional cuando aplique;
- mapeo de usuario y restaurante para Auth/RLS.

## Estado General

Estado: En progreso, con base local funcional y esquema remoto inicial aplicado.

La app local ya opera con Drift/SQLite y cola de sincronizacion. El proyecto
remoto `SmooControl` ya tiene la migracion inicial y seeds base aplicados; antes
de conectar la app en produccion deben cerrarse los mapeos de restaurante,
usuario autenticado, codigos y payloads de sync.

## Ready

| Area | Estado | Evidencia |
| --- | --- | --- |
| IDs locales estables | Ready | Entidades locales usan `id` propio y `remote_id` por `SyncColumns`. |
| Metadatos sync | Ready | Tablas operativas locales incluyen `remote_id`, `sync_status`, `sync_error`, `created_at`, `updated_at`, `synced_at`. |
| Cola sync local | Ready | `local_sync_queue`, `SyncQueueRepository`, `SyncQueueProcessor`. |
| Sync remoto desacoplado | Ready | `ISyncRemoteSender` permite conectar Supabase sin cambiar repositorios locales. |
| Auditoria local | Ready | `local_audit_logs` y repositorio de auditoria local. |
| Proyecto remoto SmooControl | Ready parcial | Proyecto `hexejdgbcmyiyqtvfihr` enlazado, migracion inicial aplicada, seed base aplicado y RLS habilitado. |
| Categorias multinivel | Ready | Local `parent_id`; remoto `product_categories.parent_id`. |
| Productos con disponibilidad POS | Ready | Local `is_available_in_pos`; remoto `products.is_available_in_pos`. |
| Modificadores POS | Ready | Local `local_modifier_groups`, `local_modifier_options` y `modifier_group_ids_json`; remoto `modifier_groups`, `modifier_options` y `product_modifier_groups`. |
| Ventas con detalle historico | Ready parcial | Local conserva producto, categoria, precio/costo y opciones; remoto tiene campos equivalentes. |
| Caja diaria | Ready parcial | Local guarda caja diaria; remoto tiene `cash_register_sessions`. |
| Gastos operativos | Ready parcial | Local y remoto tienen categoria, caja, monto, descripcion y usuario creador. |
| Roles/permisos | Ready parcial | Codigos de permisos y seeds existen; requiere mapeo final con Auth. |
| Settings de negocio | Ready parcial | Local `local_business_settings`; remoto reparte datos entre `restaurants`, `invoice_number_settings` y `settings`. |

## Deuda Que Debe Cerrarse Antes De Supabase Remoto

| Prioridad | Hallazgo | Impacto | Accion requerida |
| --- | --- | --- | --- |
| Alta | Local no tiene `restaurant_id` por registro. | RLS remoto exige restaurante en tablas de negocio. | Definir `CurrentRestaurantService` local y agregar/mapped `restaurant_id` en payloads sync. |
| Alta | `CurrentOperatorService` usa `usuario-local`. | Supabase exige `auth.users.id` en caja, ventas, gastos y auditoria. | Reemplazar por usuario autenticado o crear mapeo temporal documentado antes de `db push` remoto. |
| Alta | Productos locales no tienen `code`. | Remoto exige `products.code` unico por restaurante. | Agregar codigo interno autogenerado o cambiar migracion remota para permitir codigo derivado del local id. |
| Alta | Metodos de pago locales no tienen `code`. | Remoto exige `payment_methods.code`. | Agregar codigo estable autogenerado o mapear desde nombre normalizado antes de sync. |
| Alta | Ventas locales no guardan `user_id`. | Remoto exige `sales.user_id`. | Guardar operador en la venta local o resolverlo en payload al sincronizar. |
| Alta | `profiles.email` remoto es obligatorio. | Si se oculta correo en UI, Auth necesita otro mapeo. | Mantener correo para Auth o documentar flujo de perfil operativo sin login hasta activar Auth. |
| Media | Local `LocalBusinessSettings` combina datos de restaurante y numeracion. | Remoto divide `restaurants`, `invoice_number_settings`, `settings`. | Crear mapeador de sync claro para settings. |
| Media | Local `LocalSaleItems` no guarda `product_code`. | Remoto `sale_items.product_code` es obligatorio. | Derivar de producto/local id o persistir codigo historico en venta. |
| Media | Local caja guarda solo `physicalClosingCashInCents`. | Remoto separa contado, esperado, diferencia y comentario. | Alinear modelo local si se requiere reporte remoto completo. |
| Media | RLS existe pero no se probo en proyecto real. | Riesgo de bloqueo al sincronizar. | Validar policies con usuarios reales en Supabase nuevo. |
| Baja | Montos local en centavos, remoto numeric. | Requiere transformacion. | Convertir centavos a decimal al enviar y decimal a centavos al leer. |

## Modulos Listos Para Seguir Localmente

- POS, siempre que nuevas ventas conserven suficiente metadata para sync.
- Caja diaria, manteniendo operador centralizado.
- Gastos, manteniendo categoria y caja vinculadas internamente.
- Catalogos, si cada alta genera payload sync.
- Reportes locales, porque se basan en historico local.

## Modulos Que No Deben Marcarsen Como Finales Hasta Supabase

- Sync remoto.
- Perfiles multiusuario asociados a `auth.users`.
- Migracion de datos locales a remoto.

## Reglas Para Nuevos Cambios

- No introducir campos temporales escritos manualmente en UI.
- Todo dato temporal debe vivir en un servicio centralizado.
- Todo nuevo catalogo debe tener codigo remoto o mapeo remoto definido.
- Todo nuevo movimiento operativo debe incluir `restaurant_id` y usuario en el
  payload de sync, aunque localmente se resuelvan por servicios.
- No cambiar migraciones remotas sin actualizar `DATABASE.md`,
  `SUPABASE_PLAN.md` y esta auditoria.

## Decision Actual

Se puede continuar finalizando V1 local y el esquema remoto base ya existe, pero
la app no se considerara conectada a Supabase en produccion hasta cerrar los
hallazgos de prioridad alta y reemplazar el enviador remoto deshabilitado.
