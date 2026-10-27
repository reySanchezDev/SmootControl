# Plan De Implementacion: Vacaciones Y Dias A Cuenta

## Objetivo

Agregar un modulo de vacaciones para registrar, solicitar, aprobar y reportar
dias tomados o programados por empleado, integrado con el marcador y el
backoffice, sin afectar ventas, caja, planilla ni marcadas existentes.

## Auditoria Inicial

| Area | Hallazgo | Decision |
|---|---|---|
| Marcador | Ya existe flujo local/offline con cola sync para marcadas. | Las solicitudes desde marcador usaran el mismo patron local + sync. |
| Admin | Las pantallas admin leen/escriben remoto directo. | Vacaciones admin sera 100% Supabase directo. |
| Empleados | Existe catalogo remoto/local de empleados, pero no fecha base de vacaciones. | Agregar `vacation_accrual_start_date` a empleados. |
| Reglas | Existe catalogo de reglas de negocio. | Agregar regla `vacation_days_per_month`, default 2.5. |
| Reportes | Ya existen reportes con filtros y tarjetas moviles. | Crear reporte compacto de saldos de vacaciones. |
| Permisos | Hay permisos por ruta y modulo. | Agregar permisos especificos de vacaciones. |

## Alcance V1

- Solicitar vacaciones desde APK marcador seleccionando empleado.
- Registrar vacaciones desde backoffice:
  - dias ya tomados;
  - dias programados futuros.
- Aprobar o rechazar solicitudes hechas desde marcador.
- Backoffice puede crear registros ya aprobados cuando corresponda.
- Eliminar permanentemente registros no pagados ni bloqueados por procesos
  futuros.
- Reporte consolidado por todos los empleados o un empleado especifico.

## Reglas Funcionales

- Estados: `pending`, `approved`, `rejected`, `cancelled`.
- Tipos: `taken` para dias ya tomados, `planned` para dias programados.
- Origen: `time_clock` o `admin`.
- Las solicitudes del marcador nacen como `pending`.
- Los registros creados desde admin pueden crearse como `approved`.
- Los dias se calculan inclusivos: del 12 al 15 son 4 dias en V1.
- V1 no descuenta fines de semana ni feriados automaticamente.
- El acumulado se calcula con la regla `vacation_days_per_month` desde la
  fecha base del empleado hasta la fecha del reporte.

## Modelo Propuesto

- `employees.vacation_accrual_start_date`
- `business_rules.key = vacation_days_per_month`
- `employee_vacation_requests`
  - empleado;
  - fecha inicio;
  - fecha fin;
  - dias solicitados;
  - tipo;
  - estado;
  - origen;
  - dispositivo;
  - usuario que aprobo;
  - auditoria basica.

## Pantallas

- Backoffice: `Vacaciones`
  - bandeja de solicitudes y registros;
  - filtros por rango, empleado y estado;
  - crear registro;
  - aprobar, rechazar y eliminar.
- Marcador:
  - accion para solicitar vacaciones desde empleado seleccionado.
- Reportes: `Vacaciones`
  - consolidado de acumulado, tomado, programado, saldo actual y saldo
    proyectado.

## Etapas

- [x] Auditoria inicial.
- [x] Crear documento de plan.
- [x] Migracion Supabase y RPCs.
- [x] Modelo local/remoto y sincronizacion.
- [x] Pantalla admin de vacaciones.
- [x] Solicitud desde marcador.
- [x] Reporte consolidado.
- [x] Pruebas y documentacion final.

## Pruebas Requeridas

- Crear solicitud desde marcador y verla como pendiente en admin.
- Aprobar solicitud y verla reflejada en el reporte.
- Crear vacaciones tomadas desde admin como aprobadas.
- Crear vacaciones programadas futuras y ver saldo proyectado.
- Reintentar sync sin duplicar solicitudes.
- Filtrar reporte por empleado.
- Confirmar que POS, caja, ventas y marcadas existentes siguen funcionando.

## Avance

- 2026-08-10: Migraciones `082` y `083` aplicadas en Supabase.
- 2026-08-10: Agregada tabla local `LocalVacationRequests` y schema Drift 34.
- 2026-08-10: Agregado sync `employee_vacation_requests` con RPC de dispositivo.
- 2026-08-10: Agregadas pantallas `Vacaciones` y `Reporte de vacaciones`.
- 2026-08-10: Agregada accion `Vacaciones` en el APK marcador.
- 2026-08-10: `flutter analyze` sin issues.
- 2026-08-11: Separados widgets/formularios nuevos para cumplir regla de
  archivos menores a 300 lineas.
- 2026-08-11: `flutter analyze` sin issues.
- 2026-08-11: `flutter test test\core\database\app_database_test.dart`
  aprobado.
