# F1 — Matriz verificable de rutas y experiencias

**Fuente:** código `main` del 03-11-2026 (`AppRoutes`, `AppRouter`, `RouteAccess`, `BackofficeHomePage`, `AuthGate` y `SmooControlApp`). **Alcance:** las 47 rutas nominales registradas en `AppRoutes`; la existencia de rutas indirectas/dinámicas se valida durante F2.

**Regla:** experiencia funcional ≠ tamaño. Las rutas de POS se presentan en teléfono/tableta según restricciones; Backoffice conserva su identidad en cualquier tamaño. Time Clock tiene entrada por `SMOO_APP_MODE=time_clock` y **no** por `AppRoutes`.

## Inventario de rutas declaradas

| Clave | Ruta | Experiencia prevista | En sidebar | Permiso(s) según código | Guarda conectividad |
|---|---|---|---|---|---|
| `dashboard` | `/` | Backoffice | Sí | sin código explícito (revisar) | No declarado |
| `pos` | `/pos` | POS | No (subruta/alternativa) | ventas.registrar | No declarado |
| `reports` | `/reports` | Backoffice | Sí | reportes.ver | AdminOnlineGuard |
| `reportSummary` | `/reports/summary` | Backoffice | No (subruta/alternativa) | reportes.ver | AdminOnlineGuard |
| `cashClosingReport` | `/reports/cash-closing` | Backoffice | No (subruta/alternativa) | reportes.ver | AdminOnlineGuard |
| `dailySalesReport` | `/reports/daily-sales` | Backoffice | No (subruta/alternativa) | reportes.ver | AdminOnlineGuard |
| `productPerformanceReport` | `/reports/product-performance` | Backoffice | No (subruta/alternativa) | reportes.ver | AdminOnlineGuard |
| `expensesReport` | `/reports/expenses` | Backoffice | No (subruta/alternativa) | reportes.ver | AdminOnlineGuard |
| `monthlyOperationalReport` | `/reports/monthly-operational` | Backoffice | No (subruta/alternativa) | reportes.ver | AdminOnlineGuard |
| `inventoryValueReport` | `/reports/inventory-value` | Backoffice | No (subruta/alternativa) | reportes.ver | AdminOnlineGuard |
| `negativeInventoryReport` | `/reports/negative-inventory` | Backoffice | No (subruta/alternativa) | reportes.ver | AdminOnlineGuard |
| `payrollPaymentsReport` | `/reports/payroll-payments` | Backoffice | No (subruta/alternativa) | reportes.ver | AdminOnlineGuard |
| `salaryAdvancesReport` | `/reports/salary-advances` | Backoffice | No (subruta/alternativa) | planilla.gestionar | AdminOnlineGuard |
| `attendanceReport` | `/reports/attendance` | Backoffice | No (subruta/alternativa) | reportes.marcadas.ver | AdminOnlineGuard |
| `vacationSummaryReport` | `/reports/vacations` | Backoffice | No (subruta/alternativa) | reportes.vacaciones.ver | AdminOnlineGuard |
| `catalog` | `/catalog` | Backoffice | Sí | productos.gestionar | AdminOnlineGuard |
| `products` | `/products` | Backoffice | Sí | productos.gestionar | AdminOnlineGuard |
| `recipes` | `/recipes` | Backoffice | Sí | productos.gestionar | AdminOnlineGuard |
| `measurementUnits` | `/measurement-units` | Backoffice | Sí | productos.gestionar | AdminOnlineGuard |
| `inventory` | `/inventory` | Backoffice | Sí | inventario.gestionar | AdminOnlineGuard |
| `inventoryMovements` | `/inventory/movements` | Backoffice | Sí | inventario.gestionar | AdminOnlineGuard |
| `packaging` | `/packaging` | Backoffice | Sí | empaques.gestionar OR tipos_venta.gestionar | AdminOnlineGuard |
| `modifiers` | `/modifiers` | Backoffice | Sí | modificadores.gestionar | AdminOnlineGuard |
| `paymentMethods` | `/payment-methods` | Backoffice | Sí | pagos.gestionar | AdminOnlineGuard |
| `tables` | `/tables` | Backoffice | Sí | mesas.gestionar | AdminOnlineGuard |
| `sales` | `/sales` | Backoffice | Sí | ventas.registrar OR ventas.anular OR pdf.generar | AdminOnlineGuard |
| `cashRegisters` | `/cash-registers` | Backoffice | Sí | caja.aperturar OR caja.cerrar | AdminOnlineGuard |
| `expenses` | `/expenses` | Backoffice | Sí | gastos.registrar OR gastos.categorias.gestionar | AdminOnlineGuard |
| `settings` | `/settings` | Backoffice | Sí | configuracion.gestionar | AdminOnlineGuard |
| `exchangeRates` | `/exchange-rates` | Backoffice | Sí | tasas.gestionar | AdminOnlineGuard |
| `roles` | `/roles` | Backoffice | Sí | roles.gestionar | AdminOnlineGuard |
| `users` | `/users` | Backoffice | Sí | usuarios.gestionar | AdminOnlineGuard |
| `audit` | `/audit` | Backoffice | Sí | auditoria.ver | AdminOnlineGuard |
| `staff` | `/staff` | Backoffice | Sí | personal.gestionar | AdminOnlineGuard |
| `staffPositions` | `/staff-positions` | Backoffice | No (subruta/alternativa) | personal.gestionar | AdminOnlineGuard |
| `staffConsumptions` | `/staff-consumptions` | Backoffice | No (subruta/alternativa) | personal.consumos.ver | AdminOnlineGuard |
| `rawMaterialStaffConsumptions` | `/staff/raw-material-consumptions` | Backoffice | No (subruta/alternativa) | personal.consumos_materia.ver | AdminOnlineGuard |
| `salaryAdvances` | `/salary-advances` | Backoffice | No (subruta/alternativa) | personal.adelantos.gestionar | AdminOnlineGuard |
| `payroll` | `/payroll` | Backoffice | Sí | planilla.gestionar | AdminOnlineGuard |
| `staffOvertime` | `/staff-overtime` | Backoffice | No (subruta/alternativa) | planilla.gestionar | AdminOnlineGuard |
| `attendance` | `/attendance` | Backoffice | Sí | marcadas.gestionar OR marcadas.ver | AdminOnlineGuard |
| `vacations` | `/vacations` | Backoffice | Sí | vacaciones.gestionar OR vacaciones.ver | AdminOnlineGuard |
| `overtimeApprovals` | `/overtime-approvals` | Backoffice | No (subruta/alternativa) | horas_extra.autorizar | AdminOnlineGuard |
| `staffPayrollPayments` | `/staff/payroll-payments` | Backoffice | No (subruta/alternativa) | planilla.gestionar | AdminOnlineGuard |
| `businessRules` | `/business-rules` | Backoffice | No (subruta/alternativa) | reglas_negocio.gestionar | AdminOnlineGuard |
| `sync` | `/sync` | Backoffice | No (subruta/alternativa) | sync.configurar | No declarado |
| `systemMaintenance` | `/system-maintenance` | Backoffice | No (subruta/alternativa) | sistema.reiniciar_operacion | AdminOnlineGuard |

**Interpretación:** «experiencia prevista» refleja el destino del producto, no significa que `AppRouter` ya impida abrirla desde otra sesión. `RouteAccessGuard` verifica códigos de permiso pero no ofrece por sí solo una frontera formal de experiencias.

## Dependencias y puntos críticos

| Componente real | Propiedad | Consumidores / implicación |
|---|---|---|
| `AuthGate` + `AuthSession.isPosUser` | Compartido, decisión de entrada | Deriva `PosPage` o `BackofficeHomePage`, no depende de viewport |
| `BackofficeHomePage` | Backoffice | Destinos por permisos, `BackofficeTheme.executiveIvory` |
| `BackofficeWorkspace` y `BackofficeWorkspaceScope` | Backoffice | Tabs, `IndexedStack`, sidebar/drawer <720 |
| `PosPage`, `PosReadyView` | POS | Operación comercial; no modificar reglas |
| `PosResponsiveLayout` | POS | Composición según constraints; no es autorización |
| `ResponsiveBuilder` / `ResponsiveSize` | Compartido, presentation | Breakpoints 599/1023; no modelo de usuario |
| `AppTheme.light` | Compartido/base | MaterialApp, incluye POS |
| `BackofficeTheme.executiveIvory` | Backoffice | Scope visual dentro del árbol administrativo |
| `AppRouter`, `RouteAccessGuard` | Compartido, control de navegación | Riesgo: fallback ruta desconocida a Dashboard; ruta/permiso no equivale a experiencia |
| `AdminOnlineGuard` | Backoffice online | Sesión remota y conectividad; no prueba seguridad de API |
| `service_locator.dart` + partes DI | Compartido | Instancia local/remota; revisar inicialización por experiencia |
| `SyncSchedulerService` desde `main()` | Compartido / alto impacto | Inicia antes de resolver experiencia, preservar comportamiento |
| `TimeClockGate` | Time Clock | Entrada por define, flavor `timeClock` |
| `tool/build_web_release.ps1` | Distribución web | Flutter web + worker Drift, wasm y asset copying |
| `android/app/build.gradle.kts` | Distribución Android | Flavors production/timeClock, firmas y applicationIds existentes |

## Resultado y prioridades para F2–F4

1. **F2 — P0:** proteger rutas con un contrato explícito de experiencia además de los permisos; manejar desconocidas de forma segura. Probar navegación POS, Backoffice y Time Clock. La clasificación no modifica backend ni reglas de negocio.
2. **F3 — P1:** inventariar subpantallas, tablas y diálogos por cada destino Backoffice y verificar patrón Executive Ivory ya aprobado; PR #4 aislada pendiente de integración.
3. **F4 — P1:** comprobar inicialización global/scheduler; preservar su contrato funcional. Validación offline y build en local.
4. **F5 — P0 comercial:** permisos backend y aislamiento por restaurante requieren evidencia de servidor; no declarar seguro basándose en guards Flutter.
5. **F6/F7 — P0 publicación:** construir web para staging, configurar origen/DNS/TLS y validar workers y assets.

**Validación de F1:** se catalogaron todas las rutas nominales definidas en `AppRoutes`, las entradas de sidebar y los contratos centrales. Las rutas auxiliares/navegación dinámica permanecen como verificación específica en F2 y F3 para no confundir inventario estático con cobertura runtime.
