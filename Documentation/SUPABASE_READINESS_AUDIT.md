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

Estado: En progreso, con base local funcional, esquema remoto aplicado y primer
sender Supabase conectado por configuracion runtime.

La app local ya opera con Drift/SQLite y cola de sincronizacion. El proyecto
remoto `SmooControl` ya tiene migraciones y seeds base aplicados. La primera
conexion productiva usa un usuario tecnico Auth para cumplir RLS mientras la
operacion sigue identificando meseros/cajeros por usuarios locales.

## Ready

| Area | Estado | Evidencia |
| --- | --- | --- |
| IDs locales estables | Ready | Entidades locales usan `id` propio y `remote_id` por `SyncColumns`. |
| Metadatos sync | Ready | Tablas operativas locales incluyen `remote_id`, `sync_status`, `sync_error`, `created_at`, `updated_at`, `synced_at`. |
| Cola sync local | Ready | `local_sync_queue`, `SyncQueueRepository`, `SyncQueueProcessor`. |
| Sync remoto desacoplado | Ready | `ISyncRemoteSender` permite conectar Supabase sin cambiar repositorios locales. |
| Auditoria local | Ready | `local_audit_logs` y repositorio de auditoria local. |
| Proyecto remoto SmooControl | Ready | Proyecto `hexejdgbcmyiyqtvfihr` enlazado, migraciones aplicadas, seed base aplicado y RLS habilitado. |
| Contexto restaurante | Ready | `CurrentRestaurantService` resuelve `SMOO_RESTAURANT_ID` por `dart-define`. |
| Usuario remoto temporal | Ready parcial | Usuario tecnico Auth confirmado permite escritura RLS; falta Auth por operador real. |
| Categorias multinivel | Ready | Local `parent_id`; remoto `product_categories.parent_id`. |
| Productos con disponibilidad POS | Ready | Local `is_available_in_pos`; remoto `products.is_available_in_pos`. |
| Modificadores POS | Ready | Local `local_modifier_groups`, `local_modifier_options` y `modifier_group_ids_json`; remoto `modifier_groups`, `modifier_options` y `product_modifier_groups`. |
| Ventas con detalle historico | Ready parcial | Local conserva producto, categoria, precio/costo y opciones; sender remoto mapea montos y usuario tecnico. |
| Caja diaria | Ready parcial | Local guarda caja diaria; sender remoto mapea cajero tecnico y fecha negocio. |
| Gastos operativos | Ready parcial | Local y remoto tienen categoria, caja, monto, descripcion y usuario creador tecnico. |
| Tasas de cambio | Ready | Local `local_exchange_rates`; remoto `exchange_rates`; sender mapea por restaurante, moneda y fecha. |
| Roles/permisos | Ready parcial | Codigos de permisos y seeds existen; requiere mapeo final con Auth. |
| Settings de negocio | Ready parcial | Local `local_business_settings`; remoto reparte datos entre `restaurants`, `invoice_number_settings` y `settings`. |

## Deuda Que Debe Cerrarse Antes De Supabase Remoto

| Prioridad | Hallazgo | Impacto | Accion requerida |
| --- | --- | --- | --- |
| Alta | Auth remoto aun no es por operador. | En Supabase las ventas/caja/gastos quedan bajo usuario tecnico, no bajo mesero/cajero real. | Reemplazar usuario tecnico por login Supabase por operador o guardar columna de operador local adicional en remoto. |
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

Se puede construir un APK conectado a Supabase para piloto/arranque controlado.
La siguiente mejora de produccion debe ser Auth remoto por operador para que la
trazabilidad en Supabase no dependa del usuario tecnico.
