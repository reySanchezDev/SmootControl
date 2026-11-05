# Kivo — arquitectura oficial de acceso, aprovisionamiento POS y transición Windows
Fecha de decisión: 2026-11-05
Estado: Fase 1 implementada en código y pendiente de ejecutar QA/build y publicar; Fase 2 planificada, no implementada.

## Contexto y decisión empresarial

Kivo (antes SmooControl) fue diseñado originalmente para un único celular Android
que combinaba operaciones POS y administración. Esa solución permitió poner en
marcha el restaurante con recursos limitados. El negocio ahora dispone del
Backoffice Web en `https://kivo.quantix.software` y planifica comprar una PC
táctil para el puesto POS. Se requiere evolución sin detener operaciones, sin
cambiar la fuente de datos remota y sin perder ventas offline.

**Decisión ADR-KIVO-001:** distinguir **experiencias y modos de acceso**, no
inferir la necesidad de aprovisionamiento únicamente a partir de la ausencia de
usuarios locales ni del tamaño de pantalla.

- **Backoffice:** experiencia administrativa online-first. Autenticación remota
  con Supabase; no restaura catálogos operativos ni registra dispositivos POS.
  Los permisos deben verificarse tanto en UI como en backend/RLS.
- **POS:** experiencia operativa offline-first. Drift/SQLite local, usuarios y
  PIN autorizados, descarga/actualización de catálogos y cola de
  sincronización con Supabase.
- **Aprovisionamiento POS:** actividad de alta/restauración de un *terminal
  operativo* y distinta del *inicio de sesión administrativo*. Requiere
  autorización remota inicial cuando el dispositivo no dispone de usuarios
  locales. No debe iniciarse por la mera apertura de una sesión administrativa.
- **Una base de código Flutter:** no implica que Android, Web y Windows tengan
  exactamente los mismos periféricos, almacenamiento o ciclo de actualización.

## Decisiones de producto por plataforma

| Plataforma | Estado | Experiencia autorizada |
|---|---|---|
| Android APK existente | Producción, preservar | POS offline; conserva flujos actuales de login y restauración; admin remoto existente |
| Navegador Web | Fase 1 | SOLO login administrador remoto + Backoffice V2; sin restauración POS ni PIN local |
| Windows táctil | Fase 2, planificada | Candidato POS Flutter Windows nativo, pendiente de auditoría de dependencias y periféricos |

La web corporativa `quantix.software` pertenece al proyecto Vercel
`pagina-quantix`; Kivo usa un proyecto independiente `kivo` con subdominio
`kivo.quantix.software`. Ningún cambio de esta fase toca la web corporativa.

## Fase 1: corrección del arranque Web (alcance del cambio)

El problema observado en navegador nuevo era el flujo:

```text
AuthSessionRequested -> getStartupMode -> no local PIN user
    -> AuthDeviceInitializationRequired -> descargar POS
```

La corrección del navegador es:

```text
Flutter Web -> AuthSessionRequested
  -> sesión remota válida? -> Backoffice
  -> sin sesión remota -> Login Web administrador
  -> autenticación Supabase -> autorización -> Backoffice
```

- No consultar `getStartupMode()` para una sesión Web sin autenticar.
- No iniciar `SyncSchedulerService` en Flutter Web: el programador procesa la
  cola local del POS y no corresponde a un Backoffice online-first.
- No exponer POS/PIN, creación de admin local ni inicialización de dispositivo
  al navegador.
- Rechazar un evento PIN local en Web, aunque se invoque por error desde UI.
- No aceptar como administrador una sesión POS local previamente presente;
  al recargar la página, un token remoto ausente o caducado exige login remoto.
- Los datos administrativos los sirven las operaciones remotas protegidas por
  `AdminOnlineGuard` y verificaciones de backend. No ejecutar
  `restoreDevice()`, `registerSyncDevice()` ni
  `pullOperationalCatalogWithAccessToken()` por acceso administrativo Web.
- Conservar `DeviceInitializationService`, `DeviceInitializationPage` y el
  proceso Android sin alterar sus contratos en esta fase.
- Corregir rótulos de la pantalla Web para mostrar Kivo, sin renombrar las
  rutas técnicas, IDs, tablas o el applicationId `com.smoocontrol.pos`.

### Limitaciones expresas

La sesión remota se conserva actualmente **en memoria** mediante
`CurrentRemoteSessionService`. Una recarga completa requerirá iniciar sesión
de nuevo; no introducir persistencia de tokens en `localStorage` sin un
diseño específico de seguridad. La primera configuración de un restaurante
remoto nuevo debe diseñarse como flujo administrativo separado, no disfrazarse
de restauración de terminal POS.

El arranque Android previo continúa comprobando la inicialización antes
de mostrar el login cuando el equipo está limpio. Esta es una compatibilidad
conservadora para no romper la APK ya instalada. La decisión objetivo de
**seleccionar POS antes de aprovisionar** queda fijada aquí, pero su ajuste
en Android debe introducirse con pruebas de instalación y recuperación en
la siguiente iteración Android controlada; no afirmar que ya se cambió.

## Fase 2: transición POS Android a Windows táctil (NO ejecutar ahora)

Objetivo: reemplazar el celular como terminal POS una vez validada la PC,
manteniendo Backoffice Web accesible desde laptop/tablet.

1. Levantar inventario del hardware: Windows, arquitectura CPU, tamaño y
   resolución táctil, impresora térmica/ESC-POS, cajón, lector código de barras,
   red y respaldo eléctrico.
2. Auditar soporte `flutter build windows`, plugins nativos, SQLite/Drift,
   rutas, permisos de carpetas, persistencia de sesión, autoarranque y
   actualizaciones. No asumir compatibilidad Windows sin pruebas.
3. Reutilizar reglas POS y sincronización; ajustar solo adapters
   multiplataforma y UI táctil comprobada. Aplicar pruebas offline prolongadas,
   recuperación de conexión, folios, idempotencia y cierre de caja.
4. Planificar migración sin doble captura: cerrar caja, esperar vaciado de
   cola de sync, comparar ventas y saldos remotos, respaldar y auditar.
5. Instalar el nuevo terminal, aprovisionarlo de forma autorizada, verificar
   impresora y ejecutar una operación controlada. Mantener el Android como
   contingencia hasta lograr aceptación operativa.
6. Retirar Android solo después del acta de aceptación y recuperación
   comprobada. No borrar base local con operaciones sin sincronizar.

### Invariantes de seguridad y datos

- Las credenciales de tipo `service_role` nunca se envían al navegador,
  APK ni cliente Windows. Usar claves públicas con autenticación y RLS.
- No cambiar `SMOO_RESTAURANT_ID`, IDs del tenant, contratos de sincronización
  ni esquema de Supabase por un rebranding visual.
- El POS guarda primero transacciones locales y sincroniza sin duplicarlas.
- La vista administrativa online muestra información central; las ventas
  offline aparecen después de sincronizarse.
- El proceso de migración no debe depender de archivos SQLite copiados
  manualmente sin estrategia transaccional validada.

## Criterios de aceptación Fase 1

- Navegador incógnito y almacenamiento vacío: login administrador de Kivo,
  sin pantalla "Inicializar dispositivo" ni descarga POS.
- El navegador no ofrece la opción POS/PIN.
- Admin autorizado inicia sesión contra Supabase y accede a Backoffice V2.
- Credenciales erróneas, token expirado, recarga y cierre de sesión regresan
  a login remoto sin arrancar restauración.
- No crear registro de nuevo dispositivo POS ni descargar catálogo
  operacional solo por acceder al Backoffice.
- Android nuevo conserva autorización/restauración POS; Android previamente
  provisionado conserva PIN local, ventas offline y sincronización.
- `flutter analyze`, tests de auth y pruebas Web/Android pertinentes pasan.
- Build Web usa `tool/build_web_release.ps1`, mantiene Worker Drift/Wasm y
  se publica **solo** en proyecto Vercel Kivo.
- Validar la carga, login e interacción con el dominio real y verificar que
  `quantix.software` no haya sufrido cambios.

## Rutas de código y documentación relacionada

- `lib/features/auth/presentation/bloc/auth_bloc.dart`
- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/features/auth/presentation/pages/auth_gate.dart`
- `lib/features/auth/domain/services/device_initialization_service.dart`
- `lib/features/auth/presentation/pages/device_initialization_page.dart`
- `lib/core/session/current_remote_session_service.dart`
- `Documentation/ONLINE_ADMIN_OFFLINE_POS_PLAN.md`
- `Documentation/KIVO_VERCEL_DEPLOYMENT.md`
