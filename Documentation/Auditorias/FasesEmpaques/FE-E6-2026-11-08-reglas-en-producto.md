# FE-E6 — Reglas de empaque desde ficha del producto

Fecha: 2026-11-08. Rama: `feature/product-packaging-rules-editor`.  
**Estado: código publicado en GitHub, pendiente de compilación, pruebas widget y QA visual. NO aprobado para producción.**

## Base

Parte de `fix/packaging-legacy-route-isolation` @ `a85eeb5896479697d20535ceb1d8be26d4caede3`. Laboratorio Supabase 87/87 migraciones; suite Codex: widget 4/4, navegación 10/10, Backoffice 35/35, ventas 23/23, inventario 7/7, sync 48/48. `flutter analyze` no concluyó por bloqueo local del analysis server.

## Cambio implementado

- En la ficha **editar producto existente**, aparece sección **Empaque y consumo** únicamente si el actor Backoffice dispone de `empaques.gestionar` (o admin). No se presenta a roles solo `productos.gestionar` ni a creación nueva sin producto persistido.
- El acceso queda inhabilitado si el formulario del producto tiene cambios pendientes, para evitar mezclar dos escrituras independientes.
- Diálogo de reglas del producto: lectura de `getRules/getSalesTypes/getPackagingItems`, filtro por `product.id`; crear y editar con `saveRule` existente; modalidades y empaques se eligen por nombre, nunca mostrando UUID.
- Mantiene identidad `rule.id` en edición; nuevas reglas reciben UUID desde `Uuid.v4()` del sistema, conforme ENG-008. Duplicado `(product_id,sales_type_id,packaging_item_id)` se impide en UI, y también se mantiene constraint SQL.
- Los cambios de reglas no guardan ni cambian datos del producto; los errores remotos se muestran al usuario. No hay migraciones SQL ni cambios de motor POS.
- El acceso UI está filtrado por permiso y los 85–87 RLS/triggers ya comprobados en laboratorio son la autoridad final.

## QA pendiente (obligatorio antes de cierre)

1. `dart format`, `dart analyze`, `flutter analyze`, test widget de ficha + diálogo y suite anterior. Corregir problemas reales de compilación/layout.
2. Probar rol admin, solo productos, solo empaques y permisos revocados durante sesión; realizar realmente CREATE/UPDATE de regla via REST con JWT del usuario apropiado. No usar service_role para probar autorización.
3. Producto existente con/sin reglas; reglas activas/inactivas, cambio de modalidad y empaque, validación de cantidad, duplicado, nombres, carga fallida. Producto nuevo no debe mostrar editor.
4. Confirmar que no es posible seleccionar otro producto desde el diálogo, no se alteran UUID, y el stock de una venta y su anulación siguen según regla original.
5. UX responsive en Backoffice desktop y móvil; acciones siempre explícitas, sin menú «Más»; disposición con teclado/zoom y estados de carga/error.
6. La pantalla de `Reglas de empaque` transversal debe seguir mostrando los mismos registros, sin duplicación.
7. No reconstruir Docker ni ejecutar `supabase db reset`; comprobar puerto loopback, 87/87 migraciones, Tentrix y 17 stashes.
8. Hay un **riesgo conocido**: la lógica de permiso UI se consulta en apertura del editor, no subscrita continuamente a cambios de rol. Backend debe seguir rechazando cada escritura al revocar permisos. Validar cierre/reapertura y sesión.
9. No declarar QA visual aprobado por simulación; corresponde al usuario.

## Restricciones

No fusionar PR, no publicar, no tocar `main`, datos reales, Tentrix ni producción. La futura política de consumo por pedido (bolsa única) se diseña aparte; el editor actual configura consumo por unidad de producto.
