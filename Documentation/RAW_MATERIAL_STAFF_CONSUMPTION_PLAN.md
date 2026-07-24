# Plan: Consumo De Personal De Materia Prima

## Objetivo

Agregar un flujo administrativo para registrar consumos de materias primas por
empleado. Debe convivir con el consumo de personal POS existente, descontarse en
planilla, separar la informacion en reportes y proteger los registros ya
pagados.

## Estado General

- Estado: Implementado y corregido.
- Fecha de inicio: 2026-07-24.
- Regla arquitectura: Admin remoto directo contra Supabase; POS no participa en
  este flujo.

## Auditoria Inicial

| Area | Hallazgo | Decision |
| --- | --- | --- |
| Consumo POS actual | Usa `sales.sale_kind = staff_consumption` y detalle en `sale_items`. | No tocar este flujo porque ya esta estable en produccion. |
| Planilla | `app_post_payroll_employee` suma consumos POS pendientes por empleado/periodo y marca `sales.payroll_run_id`. | Extender la RPC para sumar consumos de materia prima y marcarlos pagados. |
| Borrado consumo POS | Usa RPC `app_delete_staff_consumption` y rechaza consumos ligados a planilla. | Repetir la misma proteccion para materia prima. |
| Productos materia prima | Existen `products.is_raw_material`, `product_kind`, unidades y costos. | Listar solo productos `product_kind = raw_material` o `is_raw_material = true`. |
| Inventario remoto | `apply_inventory_movement` aplica movimientos atomicos e idempotentes. | Crear movimiento `staff_raw_material_consumption` para descontar stock remoto. |
| UI Admin | `staff_admin_pages.dart` agrupa personal en partes. | Agregar pantalla/listado nuevo sin agrandar archivos grandes. |

## Modelo Propuesto

Crear tablas remotas propias, en vez de guardar este caso dentro de `sales`.

Motivo:
- El consumo POS es una venta interna que nace offline en POS.
- El consumo de materia prima nace solo en Admin y no necesita factura,
  consecutivo POS ni sincronizacion local.
- Separar tablas permite reportes claros y validaciones de planilla mas simples.

Tablas:
- `employee_raw_material_consumptions`
  - `id`
  - `restaurant_id`
  - `employee_id`
  - `consumed_at`
  - `note`
  - `total_amount`
  - `payroll_run_id`
  - `created_by_user_id`
  - `created_at`
  - `updated_at`
- `employee_raw_material_consumption_lines`
  - `id`
  - `consumption_id`
  - `product_id`
  - `product_name`
  - `quantity`
  - `unit_id`
  - `unit_name`
  - `unit_code`
  - `unit_price`
  - `subtotal`

## Reglas De Negocio

- Solo se pueden seleccionar empleados activos.
- Solo se pueden seleccionar productos materia prima activos.
- La fecha de consumo es obligatoria.
- Cada linea exige producto, cantidad mayor que cero y precio mayor o igual que
  cero.
- El total del documento es la suma de lineas.
- Al guardar se descuenta inventario remoto con movimiento
  `staff_raw_material_consumption`.
- Si el consumo tiene `payroll_run_id`, no se puede editar ni eliminar.
- En planilla, consumo POS y consumo de materia prima deben verse separados,
  pero ambos descuentan del neto a pagar.

## Etapas

| Etapa | Estado | Alcance |
| --- | --- | --- |
| 1. Auditoria y plan | Completado | Revisar flujo actual y crear este documento. |
| 2. Migracion Supabase | Completado | Migraciones 072 a 079 aplicadas en Supabase. |
| 3. Dominio y repositorio | Completado | Entidades y metodos remotos admin. |
| 4. UI Admin | Completado | Pantalla listado y pantalla/dialogo de registro/edicion. |
| 5. Planilla y reportes | Completado | Mostrar separado POS vs materia prima y descontar ambos. |
| 6. Validacion | Completado parcial | `flutter analyze` limpio; prueba PDF bloqueada por crash de Flutter al copiar `sqlite3.dll`. |
| 7. Release | Completado | Version `0.1.88+93`, APK reconstruido en `release/SmooControl-produccion.apk`. |
| 8. Correccion post-prueba | Completado | Migracion 080 alinea `apply_inventory_movement` con el tipo `staff_raw_material_consumption`. |

## Correcciones Post-Prueba

- 2026-07-24: Se detecto que el `CHECK` de `inventory_movements`
  permitia `staff_raw_material_consumption`, pero la RPC
  `apply_inventory_movement` conservaba una lista cerrada anterior. La
  migracion 080 reemplaza la RPC y deja permitido el mismo tipo en ambos
  puntos de validacion.

## Pruebas Minimas

- Crear consumo de materia prima con una linea.
- Crear consumo con varias materias primas.
- Validar que no permite guardar sin empleado, fecha, cantidad o precio valido.
- Confirmar que el inventario remoto descuenta la cantidad.
- Confirmar que aparece en listado del mes actual ordenado reciente primero.
- Editar un consumo no pagado.
- Eliminar un consumo no pagado y revertir inventario.
- Pagar planilla y confirmar que el consumo se descuenta.
- Confirmar que despues de pagar no permite editar ni eliminar.
- Confirmar que los consumos POS existentes siguen funcionando.

## Riesgos

- Cambiar planilla puede afectar produccion. Mitigacion: mantener campos
  existentes y agregar campos nuevos opcionales en `details`.
- El movimiento de inventario debe ser reversible al editar/eliminar. Mitigacion:
  usar ids deterministas por linea y movimiento inverso permanente.
- Reportes existentes pueden leer solo `staff_consumption_amount`. Mitigacion:
  conservar ese campo como total descontado y agregar desglose en `details`.
