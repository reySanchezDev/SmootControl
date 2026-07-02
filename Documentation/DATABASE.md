# Base De Datos - SmooControl

## Lineamientos

- Supabase remoto debe ser un proyecto nuevo llamado `SmooControl`.
- No usar el proyecto `MemberShip`.
- Las migraciones viven en `supabase/migrations`.
- Cada tabla operativa debe tener auditoria basica.
- RLS debe estar habilitado en tablas de negocio.
- Todo modulo local debe cumplir `Documentation/SUPABASE_READINESS_AUDIT.md`
  antes de considerarse listo para migracion remota.

## Tablas Iniciales

| Tabla | Proposito |
| --- | --- |
| `restaurants` | Datos del restaurante y configuracion fiscal visible. |
| `profiles` | Vinculo de usuario Supabase Auth con restaurante. |
| `roles` | Roles granulares del restaurante, con descripcion opcional. |
| `permissions` | Permisos por accion, con codigo estable alineado a la app. |
| `role_permissions` | Permisos asignados a roles. |
| `restaurant_tables` | Mesas del restaurante, con nombre interno y nombre operativo temporal para POS. |
| `table_accounts` | Cuentas separadas por mesa, usadas para cobrar divisiones una por una. |
| `product_categories` | Categorias y subcategorias. |
| `products` | Productos vendibles con disponibilidad diaria, bandera `tracks_inventory` y compatibilidad legacy de opciones embebidas. |
| `inventory_stock` | Stock actual por producto que controla inventario. |
| `inventory_movements` | Movimientos auditables de inventario: compras, ventas y anulaciones. |
| `modifier_groups` | Grupos reutilizables para POS como `Bastimento`, `Guarnicion` o `Salsa`. |
| `modifier_options` | Opciones administrables por grupo, con disponibilidad diaria en POS. |
| `product_modifier_groups` | Relacion entre productos vendibles y grupos modificadores reutilizables. |
| `payment_methods` | Arbol de metodos de pago para POS: grupos de navegacion y opciones cobrables con moneda, referencia y afectacion de caja. |
| `exchange_rates` | Tasas de cambio diarias por moneda para convertir cobros extranjeros a moneda local. |
| `invoice_number_settings` | Numeracion de comprobantes. |
| `cash_register_sessions` | Caja diaria por cajero. |
| `sales` | Ventas y estado. |
| `sale_items` | Detalle historico de ventas, incluyendo opciones seleccionadas. |
| `sale_voids` | Anulaciones auditables. |
| `expense_categories` | Categorias de gastos agrupables por `parent_id`. |
| `operating_expenses` | Gastos operativos. |
| `sync_logs` | Bitacora de sincronizacion. |
| `audit_logs` | Auditoria funcional. |

## Estados Canonicos

- Sync: `pending`, `syncing`, `synced`, `error`.
- Venta: `completed`, `voided`.
- Caja: `open`, `closed`.
- Cuenta: `open`, `invoiced`, `voided`.

## Base Local Drift

Tablas locales creadas:

- `local_product_categories`
- `local_products` (`is_available_in_pos` permite ocultar productos del POS sin inactivarlos; `tracks_inventory` indica si valida y descuenta inventario; `modifier_group_ids_json` asigna grupos reutilizables; `option_groups_json` queda como compatibilidad legacy)
- `local_inventory_stock` (stock local actual por producto; se descarga desde Supabase y se actualiza por movimientos locales)
- `local_inventory_movements` (bitacora idempotente de movimientos `purchase`, `sale` y `sale_void`)
- `local_modifier_groups`
- `local_modifier_options`
- `local_payment_methods` (`parent_id` permite jerarquia tipo `Transferencias > BANPRO > Cuenta`; `is_payment_target` distingue grupos de navegacion de opciones cobrables)
- `local_exchange_rates` (tasas por moneda y fecha de negocio; `rate_in_cents` guarda la tasa con dos decimales, por ejemplo 36.60 como 3660)
- `local_pos_open_ticket_lines` (borradores locales de pedidos abiertos por mesa para recuperar el POS despues de salir y volver a ingresar)
- `local_restaurant_tables` (`display_name` permite mostrar una referencia operativa temporal sin cambiar el nombre interno usado en reportes)
- `local_table_accounts`
- `local_sales` (`cash_register_session_id` nullable vincula ventas con caja diaria abierta)
- `local_sale_items` (`selected_options_label` conserva las opciones elegidas al vender)
- `local_sale_voids`
- `local_cash_register_sessions`
- `local_expense_categories` (`parent_id` nullable permite agrupar gastos como administrativos, combustible o mantenimiento)
- `local_operating_expenses` (`cash_register_session_id` nullable vincula gastos con caja diaria abierta)
- `local_business_settings`
- `local_sync_queue`
- `local_roles`
- `local_permissions`
- `local_role_permissions`
- `local_user_profiles` (`pin_salt` y `pin_hash` permiten login local por PIN sin guardar el PIN plano; `is_pos_user` dirige el inicio al flujo POS)
- `local_audit_logs`

Cada tabla operativa local incluye metadatos de sincronizacion:

- `remote_id`
- `sync_status`
- `sync_error`
- `created_at`
- `updated_at`
- `synced_at`

## Pendiente Remoto

- Configurar Google Auth en proyecto nuevo si se usara como proveedor de login.
- Reemplazar el sesion remota de sincronizacion por usuarios Auth reales para
  trazabilidad remota por operador.
- Implementar ciclo persistente de cuentas hijas confirmadas en POS:
  `open`, `invoiced`, visibilidad en fila de mesas, edicion de division y liberacion de la mesa original cuando todas las hijas esten pagadas.
- Definir si `local_pos_open_ticket_lines` se sincroniza a Supabase para uso
  multi-dispositivo o si queda como borrador estrictamente local de terminal.

## Validado Local/Web

- Migracion inicial documentada en `supabase/migrations/001_initial_schema.sql`.
- Drift local operativo con SQLite en memoria para pruebas.
- Assets Web requeridos por Drift agregados y copiados por `tool/build_web_release.ps1`.

## Validado Remoto Supabase

- Proyecto `SmooControl` enlazado con ref `hexejdgbcmyiyqtvfihr`.
- Migracion remota `001_initial_schema.sql` aplicada.
- Migracion remota `002_sync_writes_and_exchange_rates.sql` aplicada.
- Seed remoto aplicado con permisos, roles, metodos de pago y categorias de gasto base.
- RLS habilitado en 23 de 23 tablas publicas.
- RLS validado con sesion remota autenticada y escritura de prueba en
  `expense_categories`, `payment_methods` y `exchange_rates`.
- `supabase db lint --linked --schema public` sin errores de esquema.

