# Auditoria De Limpieza Modular En Utilidades

Fecha: 2026-07-10

## Objetivo

Separar la pantalla `Utilidades` en acciones de limpieza controladas por
modulo, para poder borrar datos de pruebas de preproduccion sin eliminar otros
movimientos que todavia se quieran conservar.

La regla base es:

- los catalogos se conservan;
- empleados y puestos se conservan;
- usuarios, roles, permisos y configuracion se conservan;
- cada accion borra solo movimientos del modulo indicado;
- el reinicio total actual se conserva para el cierre final antes de produccion.

## Estado Actual

La pantalla `Utilidades` llama a `PilotOperationResetService`, que ejecuta la
RPC remota `reset_pilot_operation` y luego limpia datos locales.

Archivos relevantes:

- `lib/features/system/presentation/pages/pilot_operation_reset_page.dart`
- `lib/features/system/data/services/pilot_operation_reset_service.dart`
- `supabase/migrations/026_reset_pilot_operation_staff_payroll.sql`

La accion actual es global. Borra:

- ventas normales;
- consumos de personal;
- detalle de ventas;
- anulaciones;
- sesiones de caja;
- gastos;
- adelantos;
- planilla;
- cuentas separadas;
- movimientos de inventario;
- movimientos de empaque;
- logs/cola de sincronizacion;
- tickets abiertos locales;
- reinicia inventario, empaques, facturas y consecutivo de consumo.

## Dependencias Clave

### Ventas

Tablas remotas:

- `sales`
- `sale_items`
- `sale_voids`
- `table_accounts`
- `cash_register_sessions`
- `inventory_movements`
- `packaging_movements`

Campos importantes:

- `sales.sale_kind`: distingue `sale` de `staff_consumption`.
- `sales.cash_register_session_id`: referencia caja.
- `sales.table_account_id`: referencia cuenta separada.
- `sale_items.sale_id`: detalle de venta con `ON DELETE CASCADE`.
- `sale_voids.sale_id`: referencia venta anulada.

Tablas locales:

- `local_sales`
- `local_sale_items`
- `local_sale_voids`
- `local_table_accounts`
- `local_cash_register_sessions`
- `local_inventory_movements`
- `local_packaging_movements`
- `local_sync_queue`

Cola sync relacionada:

- `entityType = sales`
- `entityType = cash_register_sessions`
- movimientos via payload de ventas.

### Gastos

Tablas remotas:

- `operating_expenses`
- `expense_categories` se conserva.

Campos importantes:

- `operating_expenses.expense_kind = operational` para gastos normales.
- `operating_expenses.expense_kind = salary_advance` para egresos tecnicos
  generados por adelantos que afectan caja.

Tablas locales:

- `local_operating_expenses`
- `local_expense_categories` se conserva.
- `local_sync_queue`

Cola sync relacionada:

- `entityType = operating_expenses`

### Adelantos

Tablas remotas:

- `employee_salary_advances`
- `operating_expenses` solo cuando `expense_kind = salary_advance`.

Campos importantes:

- `employee_salary_advances.employee_id`: referencia empleado, el empleado se
  conserva.
- `employee_salary_advances.cash_register_session_id`: puede referenciar caja.
- `employee_salary_advances.status`: `pending`, `partially_paid`, `paid`,
  `voided`.

Tablas locales:

- `local_salary_advances`
- `local_operating_expenses` solo si el adelanto afecto caja.
- `local_sync_queue`

Cola sync relacionada:

- `entityType = salary_advances`
- `entityType = operating_expenses` cuando el payload tenga
  `expenseKind = salary_advance`.

### Planilla

Tablas remotas:

- `payroll_runs`
- `payroll_run_lines`

Campos importantes:

- `payroll_run_lines.payroll_run_id` tiene `ON DELETE CASCADE` desde
  `payroll_runs`.
- `sales.payroll_run_id` marca consumos ya aplicados a planilla.

Tablas locales:

- No hay cache local completa de planilla; admin lee remoto.

Riesgo:

- Si se borra planilla, hay que limpiar `sales.payroll_run_id` en consumos de
  personal para que esos consumos vuelvan a estar disponibles o se puedan
  limpiar despues.
- Si la intencion es borrar planilla y tambien los consumos, ejecutar primero
  planilla o hacerlo en una RPC compuesta.

### Consumo De Personal

Tablas remotas:

- `sales` con `sale_kind = staff_consumption`
- `sale_items`
- `inventory_movements`
- `packaging_movements`
- `staff_consumption_number_settings`

Campos importantes:

- `sales.internal_receipt_number`: consecutivo interno de consumo.
- `sales.employee_id`: empleado, se conserva.
- `sales.payroll_run_id`: si esta ligado a planilla, requiere tratar planilla.

Tablas locales:

- `local_sales` con `saleKind = staff_consumption`
- `local_sale_items`
- `local_inventory_movements`
- `local_packaging_movements`
- `local_sync_queue`

Cola sync relacionada:

- `entityType = sales` cuyo payload `sale.saleKind = staff_consumption`.

## Matriz De Acciones

### 1. Limpiar Ventas POS

Debe borrar remoto:

- `sale_voids` de ventas normales;
- `sale_items` de ventas normales;
- `sales` donde `sale_kind = sale`;
- `table_accounts` sin dependencias pendientes;
- `inventory_movements` con `reference_type IN ('sale', 'sale_void')`;
- `packaging_movements` con `reference_type IN ('sale', 'sale_void')`.

Debe limpiar local:

- `local_sale_voids`;
- `local_sale_items` ligados a `local_sales.saleKind = sale`;
- `local_sales` donde `saleKind = sale`;
- `local_table_accounts`;
- `local_inventory_movements` con `movementType` de venta/anulacion;
- `local_packaging_movements` con `movementType` de venta/anulacion;
- `local_pos_open_ticket_lines`;
- `local_pos_order_contexts`;
- `local_sync_queue` donde `entityType = sales` y corresponde a venta normal.

Opcional:

- Reiniciar consecutivo fiscal (`invoice_number_settings.next_number`).
- Limpiar sesiones de caja solo si la accion se llama claramente
  `Limpiar ventas y caja`.

Debe conservar:

- productos;
- categorias;
- metodos de pago;
- mesas;
- usuarios;
- empleados;
- consumos de personal;
- adelantos;
- planilla;
- categorias de gastos.

Riesgos:

- No borrar `cash_register_sessions` si quedan gastos o adelantos que la
  referencian.
- Si se reinicia consecutivo fiscal mientras existen ventas remotas, se puede
  chocar con facturas existentes.

Recomendacion:

- Separar en dos toggles: `Borrar ventas` y `Reiniciar consecutivo fiscal`.
- No borrar caja desde esta accion salvo opcion explicita.

### 2. Limpiar Gastos

Debe borrar remoto:

- `operating_expenses` donde `expense_kind = operational`.

Debe limpiar local:

- `local_operating_expenses` donde `expenseKind = operational`;
- `local_sync_queue` donde `entityType = operating_expenses` y payload
  `expenseKind = operational`.

Debe conservar:

- `expense_categories`;
- adelantos;
- egresos tecnicos de adelantos (`expense_kind = salary_advance`);
- caja;
- ventas;
- empleados.

Riesgos:

- Si se borra toda la tabla `operating_expenses`, se borran tambien adelantos
  que afectaron caja. Por eso el filtro por `expense_kind` es obligatorio.

### 3. Limpiar Adelantos

Debe borrar remoto:

- `employee_salary_advances`;
- `operating_expenses` donde `expense_kind = salary_advance`.

Debe limpiar local:

- `local_salary_advances`;
- `local_operating_expenses` donde `expenseKind = salary_advance`;
- `local_sync_queue` donde `entityType = salary_advances`;
- `local_sync_queue` donde `entityType = operating_expenses` y payload
  `expenseKind = salary_advance`.

Debe conservar:

- empleados;
- puestos;
- salarios base;
- planilla, salvo que se elija limpiar planilla tambien;
- gastos normales;
- ventas.

Riesgos:

- Si existen lineas de planilla con abonos a adelantos, al borrar adelantos hay
  que borrar o recalcular planilla. Para preproduccion, la accion debe rechazar
  si hay planilla asociada o pedir ejecutar primero `Limpiar planilla`.

Recomendacion:

- Validar existencia de `payroll_run_lines.salary_advance_deduction > 0`.
- Si existe, mostrar mensaje: limpiar planilla primero.

### 4. Limpiar Planilla

Debe borrar remoto:

- `payroll_run_lines`;
- `payroll_runs`;
- limpiar `sales.payroll_run_id = NULL` en consumos asociados.

Debe limpiar local:

- No aplica cache local completa de planilla.
- Si se agrega cache despues, debe limpiarse aqui.

Debe conservar:

- empleados;
- puestos;
- consumos de personal;
- adelantos;
- ventas;
- gastos.

Riesgos:

- Si no se limpia `sales.payroll_run_id`, los consumos quedan marcados como
  aplicados y no vuelven a salir para planilla.

Recomendacion:

- Hacer todo dentro de una RPC transaccional.

### 5. Limpiar Consumo De Personal

Debe borrar remoto:

- `sale_items` de `sales.sale_kind = staff_consumption`;
- `sales` donde `sale_kind = staff_consumption`;
- `inventory_movements` con `reference_type = staff_consumption`;
- `packaging_movements` con `reference_type = staff_consumption`;
- reiniciar `staff_consumption_number_settings.next_number = 1`.

Debe limpiar local:

- `local_sale_items` ligados a `local_sales.saleKind = staff_consumption`;
- `local_sales` donde `saleKind = staff_consumption`;
- `local_inventory_movements` con referencia/tipo de consumo de personal si
  esta disponible en payload local;
- `local_packaging_movements` con referencia/tipo de consumo de personal si
  esta disponible;
- `local_sync_queue` donde `entityType = sales` y payload
  `sale.saleKind = staff_consumption`.

Debe conservar:

- empleados;
- puestos;
- ventas normales;
- gastos;
- adelantos;
- planilla, salvo que existan consumos ya aplicados.

Riesgos:

- Si hay consumos ligados a planilla (`sales.payroll_run_id IS NOT NULL`),
  borrar consumo sin borrar planilla deja planilla historica inconsistente.

Recomendacion:

- Rechazar si hay consumos aplicados a planilla y pedir limpiar planilla primero.

### 6. Limpiar Personal Operativo

Accion compuesta para preproduccion.

Orden recomendado:

1. Limpiar planilla.
2. Limpiar consumos de personal.
3. Limpiar adelantos.

Debe conservar:

- empleados;
- puestos;
- roles;
- usuarios;
- reglas del negocio.

Debe reiniciar:

- consecutivo de consumo de personal.

Riesgos:

- Si se ejecuta en otro orden, puede fallar por dependencias de planilla.

### 7. Reinicio Total De Produccion

Debe conservarse como accion separada y peligrosa.

Debe borrar:

- ventas;
- consumos;
- gastos;
- adelantos;
- planilla;
- caja;
- tickets abiertos;
- cuentas separadas;
- movimientos de inventario/empaque;
- sync logs/cola local.

Debe reiniciar:

- stock inventario a 0;
- stock empaque a 0;
- consecutivo fiscal a inicial;
- consecutivo de consumo de personal a 1;
- estado/display temporal de mesas.

Debe conservar:

- catalogos;
- productos;
- categorias;
- empaques;
- reglas;
- metodos de pago;
- usuarios;
- roles;
- permisos;
- empleados;
- puestos;
- configuracion base.

## Riesgo Principal: Datos Que Reviven Desde POS

Como el POS es offline-first, una limpieza remota no basta.

Decision final de implementacion:

1. limpiar primero la base local del movil desde donde se ejecuta la utilidad;
2. borrar la cola local relacionada para que ese movil no reenvie pruebas;
3. ejecutar la RPC remota en Supabase;
4. registrar auditoria y marcador remoto de limpieza.

Cada accion modular debe limpiar:

- tablas locales correspondientes;
- `local_sync_queue` de entidades afectadas;
- tickets abiertos relacionados;
- contextos de orden relacionados.

Ademas, se recomienda agregar en Supabase una tabla futura:

`pilot_cleanup_markers`

Campos sugeridos:

- `restaurant_id`
- `scope`
- `cleaned_at`
- `actor_user_id`
- `details`

Las RPC de sync podrian rechazar movimientos anteriores a `cleaned_at` para
evitar que una tablet vieja vuelva a subir datos de capacitacion despues de una
limpieza.

## Recomendacion De Implementacion

No modificar la RPC global actual como primer paso.

Crear una RPC modular transaccional:

- `reset_pilot_operation_scope(p_restaurant_id, p_confirmation, p_scope)`

Alcances soportados:

- `sales`
- `expenses`
- `salary_advances`
- `payroll`
- `staff_consumptions`
- `staff_operations`

Actualizar `PilotOperationResetService` para exponer metodos por alcance.

Actualizar `Utilidades` para mostrar tarjetas separadas por seccion:

- Ventas y caja
- Gastos
- Personal
- Reinicio total

Cada tarjeta debe tener confirmacion exacta propia, por ejemplo:

- `BORRAR VENTAS`
- `BORRAR GASTOS`
- `BORRAR ADELANTOS`
- `BORRAR PLANILLA`
- `BORRAR CONSUMOS`
- `BORRAR PERSONAL OPERATIVO`
- `REINICIAR PRODUCCION`

## No Se Debe Borrar En Ninguna Limpieza Modular

- `employees`
- `employee_positions`
- `profiles`
- `roles`
- `permissions`
- `role_permissions`
- `products`
- `product_categories`
- `modifier_groups`
- `modifier_options`
- `payment_methods`
- `restaurant_tables`
- `expense_categories`
- `business_rules`
- `settings`
- `exchange_rates`
- configuracion del restaurante
