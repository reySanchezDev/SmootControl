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

## Lote F3 — Reportes administrativos (pendiente QA Codex)

Además de los submódulos de Personal, la PR #7 incluye nuevas vistas para tres reportes:

| Reporte | Cambio visual | Aspectos preservados |
|---|---|---|
| Vacaciones | Tabla ordenable de saldos, fechas, acumulados y días programados; tarjeta completa en compacto | Filtro de empleado/fecha, cálculos existentes, modo de solo lectura |
| Inventario negativo | Tabla con existencia, necesidad de regularización, costo, movimiento y referencia; tarjeta en compacto | Costos originales, resumen y búsqueda; sin acciones destructivas |
| Adelantos históricos | Tabla al desagrupar, manteniendo resumen de entregado/abonado/saldo; tarjetas al agrupar y en compacto | Estado, rango de fechas, agrupación, montos y solo lectura |

**Criterios de este lote:** una sola pasada de compilación, análisis estático, suite de pruebas, build web local y capturas de desktop/móvil de estos reportes y los módulos de Personal. Registrar las excepciones de visualización sin alterar negocio.

**Pendiente:** estos cambios todavía no se han probado localmente en Codex; no publicar ni fusionar `main`.

## Lote F3 — Acciones de creación y limpieza visual de Personal

**Código en PR #7; pendiente verificación Codex.**

- `Puestos`, `Horas extras`, `Adelantos` y `Consumo de materia prima`: sustituidos iconos de «+» sin etiqueta por acciones primarias visibles «Nuevo puesto», «Nueva hora extra», «Nuevo adelanto» y «Nuevo consumo», reutilizando `BackofficeNewAction`. Sin alterar handlers.
- Eliminado `_StaffSearchField` obsoleto después de sustituir búsquedas duplicadas por el buscador de tabla; revisado orden de importaciones en Inventario negativo.
- Queda un aviso de lint `prefer_if_element` **sin ubicación exacta reportada**; Codex debe devolver ubicación o aplicar una corrección sintáctica estrictamente equivalente, sin modificar lógica.
- El bloqueo previo de Vacaciones quedó resuelto: Codex confirmó 132/132 pruebas y build web exitoso, aunque `flutter analyze` todavía informó 1 warning y 2 infos antes de este nuevo lote.

**Gates:** validar `flutter analyze` hasta 0 avisos, pruebas Backoffice/Staff/Reportes/POS y build web oficial. Mantener locales generados en archivos privados sin commit accidental. No aprobar visualmente sin capturas reales.

## Lote transversal — consistencia, búsquedas y regresión UI (2026-11-03)

**Base validada por Codex:** `4781a5d1`, `flutter analyze` sin issues, 132/132 pruebas aprobadas y build Web oficial correcto. **Cambios posteriores NO verificados localmente.**

- **Contrato de selección global:** `BackofficeCollectionView` ahora comprueba en modo assert que las listas con comandos de selección reciban `rowKey` estable y no dupliquen columna `Acciones`. No afecta listas heredadas con acciones por fila mientras migran.
- **Etiquetas claras:** `BackofficeSelectionToolbar` rechaza nombres genéricos `Más`, `Acciones` y equivalentes, manteniendo la regla UX ya aprobada.
- **Búsqueda:** todas las listas del componente reutilizable normalizan tildes, diéresis y ñ mediante `containsNormalizedSearch`. No se cambian los datos; solo la comparación textual.
- **Sin duplicados:** `showSearch` permite que reportes con filtro superior eviten repetir el mismo campo; Inventario negativo conserva su filtro superior y oculta el interno. Adelantos históricos muestra buscador del agrupado o del listado tabular, pero no ambos simultáneamente; al cambiar de modo limpia consulta obsoleta.
- **Pruebas nuevas:** `backoffice_selection_consistency_test.dart` verifica que registros bloqueados no habiliten Eliminar, las selecciones viejas no sobrevivan a reemplazo de registros y se cumpla el contrato de columna; `backoffice_collection_search_test.dart` prueba búsquedas con tildes y ausencia de campo duplicado; `backoffice_selection_toolbar_test.dart` amplía rechazo de etiqueta genérica.

**Importante:** no hay certificación visual de estas vistas ni garantía de que el nuevo lote compile hasta Codex. Falta revisar en un navegador real los estados seleccionados, el overflow de acciones, escalas y tableros a 1366×768, 1920×1080 y compacto.

**Siguiente checkpoint agrupado:** una única actualización de PR #7 y ejecución de `dart format` (solo archivos tocados), `flutter analyze` (cero issues), pruebas compartidas y suites Backoffice/Staff/Reportes/POS, build web oficial, conservación de l10n local y comparación de diff con `main`. No merge ni despliegue.

### Nota de implementación del contrato

La comprobación de columna `Acciones` duplicada se realiza en el `build()` del componente, en modo `assert`, para no exigir evaluación constante a la construcción. La prueba ejecuta el widget en el tester y verifica la excepción. El requisito de `rowKey` estable conserva assert en constructor. Estas son protecciones de desarrollo, no sustituyen validaciones de permisos backend ni la comprobación de botones deshabilitados.

**Último código no validado por Codex:** consultar HEAD actual de `develop/backoffice-stabilization-integration`; el punto de certificación sigue siendo `4781a5d1` hasta recibir una nueva ejecución.

## Lote amplio posterior a 138/138 — Time Clock, Modificadores, Reportes

**Punto de partida certificado por Codex:** commit `04856a2099a26fcf6c44e23203d9b20020731492`, `flutter analyze` limpio, 138/138 suites Backoffice/Staff/Reportes/POS, build web correcto. **Este nuevo lote requiere nueva validación.**

**Time Clock (F2):**
- En primer intento, tres de cuatro pruebas pasaron; falló la transición de inicialización a marcador.
- Se ajustó `TimeClockGate` para no renderizar datos anteriores mientras carga un nuevo modo y se asignó una clave al `FutureBuilder` por ciclo, evitando estado anterior persistente. Se mantiene proveedor de modo y destino original sin cambios de datos.
- Volver a ejecutar las 4 pruebas, incluida transición, más análisis y regresión.

**Modificadores (F3):**
- La vista compacta ya no utiliza `PopupMenuButton` en grupos ni opciones.
- Acciones descriptivas `Editar`, `Desactivar` y `Agregar opción` visibles como comandos envueltos (`Wrap`) debajo del grupo expandido y junto a cada opción. Se mantiene protección de inactividad y callbacks originales.
- Se retiró el botón `Agregar opción` duplicado en compacto. En escritorio se preserva UX de tabla con selección global y detalle de opciones.

**Reportes (F3):**
- `reports_daily_view_part.dart`: ventas diarias ahora usa `BackofficeDataTable`, encabezado fijo, desplazamiento vertical interno y totales al final.
- `reports_expenses_view_part.dart`: gastos diarios igual, preservando resumen de categorías y total.
- `inventory_value_report_widgets.dart`: valor de inventario usa tabla común de 8 columnas, con unidades, costos, precios, proyecciones y métricas originales.
- Se mantienen tarjetas móviles. Para tablas incluidas dentro de `ListView`, se fijó una altura acotada para evitar restricciones verticales infinitas.

**Pendientes de QA:** `dart format`, `flutter analyze`, pruebas Time Clock (4/4), Backoffice/Staff/Reportes/POS, build web con Drift y comprobación visual de las tablas en escritorio, 390 px y 1366 px si hay navegador disponible. No tocar los archivos locales generados `lib/l10n/app_localizations*.dart`; no merge ni despliegue.

**Límites de este lote:** no se modificaron entidades, datos, repositorios, lógica POS ni servidor. Quedan pantallas heredadas de movimientos/ajustes/lotes, nómina, configuración y algunos diálogos, además de la aprobación visual integral.

## 2026-11-03 — Regresión Time Clock sin resolver + test explícito de Modificadores

**Punto de referencia validado:** SHA `74f527d0723e6ed412634fd07627892c7fedbc6c`. Codex confirma `flutter analyze` sin issues, 138/138 pruebas de Backoffice/Staff/Reportes/POS, build Web correcto. **Time Clock sigue en 3/4:** `initialization reload transitions to standalone marker` falla al no aparecer el texto de destino.

La revisión de código identificó que la prueba original resolvía el modo con un cierre sobre una variable `initialized`, sin comprobar si el proveedor se invocó nuevamente, si aparecía la carga o si el segundo Future se completaba. Esta información no alcanza para afirmar si el error está en el gate, la prueba o su sincronización.

**Cambios recientes en PR #7 (sin validar aún):**
- `TimeClockGate`: se añadió comprobación explícita de `ConnectionState.done` y se mantiene la clave asociada al Future de cada intento; no se cambió ningún acceso al backend.
- Test Time Clock: transición reescrita con dos `Completer` independientes; comprueba dos invocaciones al loader, estado intermedio de carga y destino final, permitiendo identificar el punto exacto de fallo.
- Test compacto de Modificadores: comprueba acciones explícitas de grupo/opción, callbacks preservados, ausencia de `PopupMenuButton` a 390 px.

**Gate de próxima ejecución:** correr primero `flutter test test/features/attendance/presentation/pages/time_clock_gate_test.dart -r expanded` y la prueba de Modificadores. Si falla Time Clock, registrar la línea exacta de expect y los contadores; no reportar la transición como corregida ni hacer modificaciones adicionales de producción sin diagnosticar. Luego `flutter analyze`, regresión Backoffice/Staff/Reportes/POS y build web solo si los tests focales lo permiten.

**Persisten:** cobertura visual de nómina, lotes, ajustes, configuración y diálogos, y revisión visual real desktop/móvil. No usar pruebas unitarias como sustituto de QA de interfaz y negocio.

## Lote adicional — Ajuste de inventario responsive

- `inventory_adjustment_widgets_part.dart`: el bloque **Existencia del sistema / Conteo / Diferencia** ya no fuerza tres columnas en ancho compacto. `LayoutBuilder` apila las secciones por debajo de 650 px; en escritorio conserva la distribución en tres columnas. `TextField`, controladores, conversiones a unidad base y `onChanged` originales permanecen.
- Revisión de `monthly_operational_report_widgets.dart`: el detalle operativo mensual actual **no usa un `DataTable` clásico**, sino tarjetas y secciones expandibles; se corrige la premisa de auditoría anterior y no se migra sin necesidad.
- Test de Modificadores añadido para acciones visibles a 390 px y rutas de grupo/opción; debe ejecutarse localmente.
- Time Clock: continúa **pendiente**, con prueba determinística y logs de invocación; no marcar F2 cerrada.

**Pendiente de certificación:** análisis, tests, build web, más revisión visual de 390px/1366px sin alterar datos productivos.

## 2026-11-03 — Historial de pagos de planilla, lote F3

En `develop/backoffice-stabilization-integration` se unificó el historial `PayrollPaymentsReportPage` con la tabla de Backoffice: columnas Empleado, Puesto, Período, Fecha de pago, Pagado y Saldo restante, con selección y acciones explícitas `Ver detalle` y `PDF esquela`. `Eliminar pago` se ofrece **solo en modo Staff Admin**; el modo `report` se mantiene de solo lectura. La operación destructiva conserva su confirmación y el handler anterior sin modificación del servicio `reverseReceipt`.

En compacto las tarjetas informativas se seleccionan para habilitar los comandos de la toolbar; no se duplican botones en cada tarjeta. Se conservan el resumen de importes y los filtros existentes (empleado, corte y fechas). No se modifican cálculos, pagos, asientos, reversión, repositorios ni permisos de servidor.

**QA incremental pendiente:** formato del archivo cambiado, `flutter analyze`, y comprobación específica de los modos `report` y `staffAdmin`. Por el riesgo de operación de reversión de planilla, validar **únicamente en widget tests con datos ficticios**, sin ejecutar mutaciones de producción. El cierre de F3 incluye prueba de permisos real y QA visual.
