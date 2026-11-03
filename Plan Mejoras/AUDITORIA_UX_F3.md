# F3 — Auditoría de la unificación visual (corte 2026-11-03)

**Base visual ya aprobada por el propietario:** Executive Ivory. No cambiar el concepto de diseño.

**Referencia de código:** `main` `c6680eb6` y cambios aislados de PR #4 `develop/backoffice-ux-unification` (aún sin integrar). Esta inspección es estática, no sustituye pruebas y revisión visual locales.

## Cambios verificados en PR #4

| Área | Archivo | Patrón revisado | Estado |
|---|---|---|---|
| Vacaciones | `vacation_requests_table_part.dart` | Selección de registro y Aprobar/Rechazar/Eliminar en botonera, sin columna Acciones | Cambio presente, validar interacción |
| Auditoría | `audit_log_page.dart` | Selección + Ver detalle sin columna Acciones | Cambio presente, validar detalle |
| Caja administrativa | `cash_register_backoffice_table.dart` | Selección + Editar/Eliminar sin columna Acciones | Cambio presente, verificar guardas y confirmación |
| Movimientos inventario | `inventory_movements_page.dart` | Selección + detalle y adaptación diálogo/escritorio | Cambio presente, verificar desktop/móvil |
| Ventas | `sales_searchable_list.dart` | Selección + detalle/PDF/Anular, sin columna Acciones | Cambio presente, verificar permisos y confirmación |
| Recibos de planilla | `payroll_payments_report_page.dart` | Diálogo escritorio / bottom sheet compacto | Cambio presente, verificar tamaños |
| Vacaciones, página | `vacation_requests_page.dart` | Cambios de UI asociados | Cambio presente, revisar flujo |

**Conclusión:** PR #4 cubre **7 archivos** y no equivale a una unificación visual integral. No declarar F3 completada ni fusionar por cobertura parcial.

## Reglas de aceptación transversal

- [ ] Todas las pantallas principales y secundarias inventariadas, con patrón de diseño coherente.
- [ ] Tablas: encabezado visible durante scroll, filtros claros, densidad profesional y accesibilidad.
- [ ] Acciones por selección de registros donde aplique; botones con etiquetas explícitas, sin menús ambiguos `Más` ni columnas `Acciones` redundantes.
- [ ] Acciones destructivas conservan permisos, confirmación y restricciones existentes.
- [ ] Formularios, diálogos y detalle: layout profesional en desktop y fallback compacto en pantalla pequeña.
- [ ] Sidebar, pestañas, restauración de foco, teclado y estados vacíos/errores revisados.
- [ ] POS teléfono/tableta conserva aspecto y funcionamiento en rama integrada.
- [ ] Pruebas local Codex, luego aceptación visual propietario; sin modificar negocio ni datos.
- [ ] Sólo integrar PR #4 cuando pase las validaciones y se autorice merge.

## Bloqueos y próximos trabajos

1. Auditar módulos administrativos restantes contra `MATRIZ_ACEPTACION.md` y `INVENTARIO_PRESENTACION.md`.
2. Identificar reutilización riesgosa de componentes compartidos.
3. Preparar rama local de integración **sin** fusionar a `main`, incluyendo PR #6 y PR #4 sólo cuando el diff y pruebas sean aceptables.
4. Solicitar a Codex build local y revisión visual al propietario **únicamente cuando haya una versión integrada suficientemente completa**.

## Lote F3 adicional — 2026-11-03

**Rama de integración PR #7:** tras validar el primer lote (44/44 tests, analyze limpio, build web correcto), se incorporaron únicamente cambios de presentación adicionales:

- `attendance_admin_table_part.dart` / `attendance_admin_page.dart`: marcadas administrativas con selección + Editar/Eliminar explícitos en barra, sin columna Acciones; reporte de solo lectura mantiene las acciones desactivadas. Se reutilizan los mismos callbacks y confirmación existente.
- `staff_positions_page_part.dart`: lista móvil de puestos transformada en `BackofficeCollectionView` con búsqueda, columnas Puesto/Estado, selección y Editar; se conserva el cuadro de edición y el comando Nuevo existentes.

**Validación pendiente:** análisis y pruebas focalizadas del nuevo HEAD en Codex. Sin cambios en dominio, entidades, repositorios, persistencia o POS.

**Hallazgos UX aún pendientes:** los submódulos de personal (consumos, horas extra, adelantos y materias primas), aprobaciones de horas extra y varios reportes usan vistas particulares; auditar según necesidad real, evitando conversión de vistas de solo lectura a edición y sin perder acciones.

## Lote ampliado de Personal — validación única pendiente

En la rama de integración se avanzaron **cuatro submódulos de administración** antes de solicitar otra ejecución local:

| Pantalla | Adaptación UX | Protecciones preservadas |
|---|---|---|
| Horas extras manuales | Tabla, columnas, ordenación, búsqueda única, selección + Editar/Eliminar | Operaciones habilitadas solo en registros pendientes |
| Consumo de materia prima | Tabla, búsqueda por producto/empleado, selección + Editar/Eliminar | Registros aplicados a planilla mantienen acciones bloqueadas |
| Adelantos de salario | Tabla, importes separados, búsqueda única, selección + Eliminar | Confirmación y rechazo backend para adelantos abonados se conservan |
| Consumos de personal | Tabla, búsqueda única, selección + Ver detalle/Eliminar | Confirmación destructiva y detalles originales intactos |

**Se eliminaron buscadores duplicados** del contenedor en esas cuatro pantallas porque la tabla reutilizable ya incorpora búsqueda integrada. Los filtros de fecha y las operaciones existentes permanecen.

**Gate:** estos cambios requieren `dart format`, `flutter analyze`, suite de pruebas Backoffice/Staff y regresión POS en el worktree de Codex; después revisión visual de las cuatro pantallas. **No constan como validados** hasta registrar resultados. No modifica entidades, repositorios, APIs ni datos.
