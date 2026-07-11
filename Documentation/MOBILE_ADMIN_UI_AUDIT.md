# Auditoria UI Movil Admin

Fecha: 2026-07-07

## Regla V1

El administrador seguira viviendo dentro del mismo APK en V1, por eso todas las pantallas admin deben ser operables desde telefono. En movil no se aceptan:

- texto partido letra por letra por falta de ancho;
- `RenderFlex overflow`;
- botones de guardar/cancelar fuera de pantalla;
- dialogs sin scroll cuando el contenido crece;
- tablas obligatorias en pantallas menores a 620 px;
- acciones criticas inaccesibles con teclado abierto.

## Hallazgo Corregido

| Modulo | Pantalla | Riesgo | Hallazgo | Accion |
| --- | --- | --- | --- | --- |
| Gestionar inventario | Registrar compra por lote productos/empaques | P0 | El dialog usaba una tabla con columnas fijas dentro de `AlertDialog`; en telefono el nombre del producto quedaba reducido a una columna de letras y el flujo era inoperable. | Corregido en `lib/features/inventory/presentation/pages/inventory_page.dart`: en movil el dialog usa ancho disponible, altura controlada, oculta encabezado tabular y muestra cada producto/empaque como tarjeta con `Cantidad` y `Costo` lado a lado. |
| Listas admin con acciones | Modificadores POS, productos, categorias, metodos de pago, mesas, gastos, ventas, roles y usuarios | P0 | Varias listas usaban `trailing: Row(...)` con muchos iconos dentro de `ListTile`/`ExpansionTile`. En telefono eso dejaba el titulo/subtitulo sin ancho y el texto se partia letra por letra. | Corregido con `lib/core/design_system/app_tile_actions.dart`: en pantallas angostas las acciones pasan a menu compacto y el texto conserva ancho. Barrido estatico sin `trailing: Row(...)` ni `trailing: Wrap(...)` en `lib/features`. |

## Matriz De Auditoria Movil

| Modulo | Archivos principales | Estado movil | Riesgo | Accion recomendada |
| --- | --- | --- | --- | --- |
| Categorias | `catalog_page.dart`, `catalog_category_tile.dart`, `create_category_dialog.dart` | Lista corregida con acciones compactas en movil; dialog vertical de 360 px. | P1 corregido | Probar alta/edicion con nombres largos; si aparece overflow, migrar a dialog responsive comun. |
| Gestionar productos | `products_page.dart`, `create_product_dialog.dart`, `modifier_group_selector.dart` | Lista corregida con acciones compactas en movil; formulario vertical con scroll. | P1 corregido | Prueba obligatoria en telefono: crear/editar producto, categoria larga, modificadores, inventario activo. |
| Gestionar inventario | `inventory_page.dart` | Compra por lote corregida para movil. | P0 corregido | Validar en APK: filtro, varias cantidades, costo, guardar productos y empaques. |
| Gestionar empaque | `packaging_page.dart` | Usa `_ResponsiveDialog` y formularios con scroll. | P2 | Mantener como referencia para futuros dialogs admin. Probar reglas con listas largas. |
| Modificadores POS | `modifiers_page.dart`, `modifier_group_tile.dart`, `modifier_dialogs.dart` | Lista corregida con acciones compactas en movil; dialogs verticales de 360 px, listas anidadas. | P1 corregido | Probar crear grupo/opcion, activar/desactivar y guardar desde telefono. |
| Metodos de pago | `payment_methods_page.dart`, `create_payment_method_dialog.dart` | Arbol/lista corregida con acciones compactas en movil y dialog vertical. | P1 corregido | Probar crear opcion dentro de grupo, editar moneda, afecta efectivo y referencia requerida. |
| Mesas | `tables_page.dart`, `create_table_dialog.dart` | Lista corregida con acciones compactas en movil; dialog sencillo de 360 px. | P1 corregido | Probar editar nombre/base y activar/desactivar. |
| Ventas | `sales_page.dart`, `sale_tile.dart`, `sale_detail_page.dart`, `sale_invoice_preview_dialog.dart` | Lista corregida con acciones compactas en movil; detalle de venta ya cambia a tarjetas bajo 620 px. | P1 corregido | Probar detalle, anulacion e impresion/preview en telefono. |
| Gastos | `expenses_page.dart`, `expenses_overview_list.dart`, `create_expense_category_dialog.dart`, `create_expense_dialog.dart` | Lista de categorias corregida con acciones compactas en movil; formularios verticales. | P1 corregido | Probar categoria y gasto con teclado abierto. |
| Configuracion | `settings_page.dart` | Vista con `ListView` y max width 720. | P2 | Probar guardar con teclado abierto y textos largos. |
| Tasa de cambio | `exchange_rates_page.dart` | Usa controles por moneda y campo de 180 px. | P1 | Probar edicion en telefono angosto; si el row aprieta, convertir cada moneda a tarjeta compacta. |
| Roles | `roles_page.dart`, `create_role_dialog.dart` | Lista corregida con acciones compactas en movil; dialog de 420 px con muchas casillas. | P1 corregido | Probar rol con todos los permisos; candidato a dialog responsive de altura controlada. |
| Usuarios | `users_page.dart`, `create_user_dialog.dart` | Lista corregida con acciones compactas en movil; dialog de 380 px con rol, POS user y PIN. | P1 corregido | Probar crear/editar usuario desde telefono y verificar botones con teclado abierto. |
| Auditoria | `audit_log_tile.dart`, pantalla de auditoria | Lista informativa. | P2 | Probar busqueda/listado con textos largos. |
| Sincronizacion | `sync_page.dart`, `sync_queue_tile.dart` | Mixta por diseno; tarjetas de 260 px dentro de `Wrap`. | P2 | Probar reintento, error largo y refresh manual. |
| Utilidades | `pilot_operation_reset_page.dart` | Panel con max width 760 y dialogs de confirmacion. | P1 | Probar en telefono antes de usar en capacitacion; revisar que la confirmacion destructiva no quede cortada. |

## Prueba Manual Obligatoria En Telefono

Para cada pantalla admin anterior:

1. Abrir en telefono real o emulador 360 x 800.
2. Activar teclado en el campo principal.
3. Crear o editar un registro con texto largo.
4. Confirmar que se ve el boton Guardar.
5. Confirmar que no hay texto vertical ni overflow amarillo/negro.
6. Guardar y refrescar desde Supabase remoto.

## Regla Para Nuevos Cambios

Todo dialog admin nuevo debe usar una de estas dos formas:

- formulario vertical con `SingleChildScrollView`, ancho maximo y `insetPadding` reducido en movil;
- lista compacta tipo tarjeta cuando haya columnas editables.

No se debe meter una tabla editable con columnas fijas dentro de un `AlertDialog` sin alternativa compacta para movil.
