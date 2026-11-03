# Plan maestro end-to-end — SmooControl como producto comercial

**Estado:** APROBACIÓN DE ALCANCE PENDIENTE · Documento de planificación, no implementación.
**Origen:** auditoría del repositorio `main` (`c6680eb6`) del 03-11-2026.
**Trabajo paralelo:** PR #4 (`develop/backoffice-ux-unification`), **sin fusionar**. No incluir esa PR de forma implícita.
**Responsables:** ChatGPT (diseño/revisión); Codex (compilación, pruebas y preview local); propietario (decisiones de dominio, hosting, aprobación y publicación).
**Objetivo:** Backoffice web de calidad comercial, desplegable en un dominio propio con HTTPS, y POS Android para móvil/tableta, sin alterar reglas de negocio, datos o experiencia POS. Mantener Time Clock existente.

## 0. Reglas innegociables

1. No cambios de reglas fiscales, ventas, tickets, pagos, inventarios, caja, costos, planillas, sincronización de payloads ni contratos de persistencia.
2. No migraciones de base de datos, cambios de esquema ni operaciones destructivas en producción.
3. No modificar `main`, releases, DNS o producción sin autorización expresa. Trabajar en rama independiente, PR revisable y rollback probado.
4. Los artefactos Android existentes conservan `applicationId`, firma y datos instalados.
5. No registrar tokens, credenciales, identificadores sensibles ni información de clientes. Las claves públicas de configuración siguen tratándose según su naturaleza y políticas de servidor.
6. Las pruebas son proporcionales al riesgo durante el trabajo; validación integral, seguridad y build release antes del merge/despliegue.
7. Cada hito tiene evidencia, propietario, resultado y criterio de cierre. Ningún `success` de CI equivale por sí solo a certificación de producción.
8. Backoffice y POS comparten dominio/repositorios de forma controlada; `ResponsiveSize` representa presentación, no autorización.

## 1. Estado real verificado y brechas

| Capacidad | Evidencia actual | Brecha/acción |
|---|---|---|
| Entrada según sesión | `AuthGate`: `session.isPosUser` abre `PosPage`; otros abren `BackofficeHomePage` | Formalizar identidad de experiencia y denegación cruzada de rutas |
| Backoffice web | `BackofficeWorkspace`: sidebar, drawer <720 px, tabs e `IndexedStack` | QA transversal desktop/tablet/móvil, accesibilidad, navegación y formularios |
| Tema | `BackofficeTheme.executiveIvory` dentro del shell administrativo | Auditar widgets compartidos y tokens para evitar regresión en POS |
| POS adaptable | `PosResponsiveLayout` calcula ancho/alto disponible; `ResponsiveBuilder` tiene 599/1023 px | Mantener layouts POS; verificar puntos reales de quiebre sin imponer otros |
| Rutas | `AppRouter`, `RouteAccessGuard`, `AdminOnlineGuard` | Matriz de exposición/permiso/experiencia; auditoría de enlaces profundos, fallback y sesiones |
| Sincronización | `main()` inicia `SyncSchedulerService` para app estándar | Auditar efectos en web sin cambiar política operativa sin pruebas |
| Build web | `tool/build_web_release.ps1`: `flutter clean`, `flutter pub get`, worker Drift, `flutter build web`, copia `sqlite3.wasm` y `drift_worker.js` | Hacer release reproducible y seguro; verificar recursos, cache, base path, hosting |
| Android | flavors `production`/`timeClock`; id POS `com.smoocontrol.pos` | Comprobar firma release y ruta de distribución; evitar fallback debug en entregable comercial |
| CI | Workflow `.github/workflows/backoffice-v2-ux-quality.yml` corre en PR a `main` y manual | Validaciones selectivas en desarrollo; gate final, evidencias y protección |
| Dominio | El propietario declara disponer de uno | Faltan FQDN exacto, DNS actual, proveedor de hosting y política de correos; no inventar valores |

**Importante:** lo anterior describe lo observado en código, NO certifica seguridad, conectividad, disponibilidad, aislamiento de tenants ni funcionamiento end-to-end en producción.

## 2. Arquitectura objetivo y límites

```text
SmooControl / repositorio Flutter
├── Core compartido: entidades, casos de uso, contratos, servicios transaccionales
├── Backoffice Web: navegación y visuales administrativos, auth remota, guardas
├── POS Android: ventas operativas y UI táctil responsive móvil/tableta, offline-first
└── Time Clock: experiencia de marcadas existente
```

Formalizar `SmooExperience { pos, backoffice, timeClock }` **solo si** reduce duplicación o ambigüedad; preferir un contrato ligero integrado en los mecanismos actuales. No crear router paralelo, BLoC paralelo, ni nuevas jerarquías de DI por estética. Clasificar cada ruta como POS/Backoffice/Time Clock/compartida y validar: autenticación + experiencia habilitada + permiso requerido. La configuración de build no reemplaza autorización del backend.

**Política de dependencias:** `features/pos/presentation` no depende de widgets de administración; `features/*/presentation` Backoffice usa design system administrativo cuando corresponde; `core/design_system` se mantiene genérico salvo componentes explícitamente nombrados `backoffice_*`; `domain` no importa Flutter UI. Documentar excepciones reales, no imponer refactorizaciones cosméticas.

## 3. Fases de ejecución y entregables

### Fase 0 — Línea base y aislamiento del trabajo
- Congelar referencia de `main`; registrar versión, Flutter/Dart/Gradle y dependencias.
- Inventariar ramas, PR #4, stashes locales, worktrees y preview; preservar estado del POS.
- Crear rama `develop/experience-isolation` desde `main` al iniciar implementación; documentación en su propia PR.
- Capturar pruebas de humo y capturas representativas **antes** de modificaciones: POS teléfono/tableta y Backoffice 390×844, 1366×768, 1920×1080.
- Definir dueño y ambiente de staging de datos no productivos; si no existe, usar pruebas con mocks y ambiente aislado, nunca ventas reales para ensayos destructivos.

**Salida:** matriz de línea base, riesgos, rollback de rama, lista de evidencias.

### Fase 1 — Inventario total de pantallas y dependencias
- Enumerar todas las rutas de `AppRoutes`, destinations en `BackofficeHomePage`, pantallas de detalle, diálogos, reportes y pantallas POS auxiliares.
- Para cada ruta documentar: experiencia, rol/permiso, requiere conexión, fuentes de datos, tema, widget compartido, resolución soportada y acciones peligrosas.
- Examinar `AppPageScaffold`, `AppButton`, `AppText`, dialogs, tablas, campos, drawers, overlays, estilos directos y helpers de navegación.
- Marcar componentes compartidos con pruebas requeridas de regresión bilateral.
- Distinguir pantalla disponible de pantalla lista para comercializar: no atribuir funcionalidades no verificadas.

**Salida:** `MATRIZ_EXPERIENCIAS.md` con cobertura exhaustiva.

### Fase 2 — Contrato de experiencia y navegación segura
- Resolver experiencia desde sesión autenticada; el viewport decide layout **dentro** de ella.
- Conservar `AuthGate`, `RouteAccessGuard` y `AdminOnlineGuard`; declarar exposición por ruta sin duplicar controles.
- Denegar rutas no permitidas (incluido deep link/bookmark), no redirigir silenciosamente a un módulo privilegiado; manejar desconocidas con pantalla 404/denegación apropiada.
- Mantener permisos de servidor; revisar comportamiento tras sesión remota expirada, cambio de rol, logout y refresh.
- Asegurar que `TimeClockGate` y `SMOO_APP_MODE=time_clock` no pierdan su entrada.

**Salida:** contrato de rutas, tests de acceso y navegación, sin cambio en casos de uso.

### Fase 3 — UX administrativa uniforme de extremo a extremo
- Consolidar Executive Ivory (tipografía, colores, densidad, foco, botones, formularios, diálogos, estados y mensajes) desde tokens compartidos administrativos.
- Revisar **todas** las entradas del menú y subpantallas; usar tablas compactas, filtros claros, encabezados fijos cuando aplique, selección de registros y acciones etiquetadas visibles.
- Eliminar columnas redundantes `Acciones` y menús ambiguos `Más` donde se haya acordado el patrón de botonera contextual. Acciones destructivas con confirmación y permisos, sin ocultar capacidades.
- Diálogos apropiados para escritorio y layouts táctiles apropiados para móviles; navegación por teclado, foco, labels, tooltips y `prefers-reduced-motion` donde corresponda.
- Usar datos reales/simulados identificados para QA; no inventar métricas ni funcionalidades. Comprobar 390×844, 768×1024, 1366×768 y 1920×1080, zoom 125%/200%, scroll horizontal justificado, largos de texto y estados vacíos.
- Integrar PR #4 **solo después** de revisar su diff, análisis, compatibilidad y conflictos; no dar por completa la UX por existencia de PR.

**Salida:** matriz pantalla→criterios UX→captura→resultado, pendientes resueltos o documentados.

### Fase 4 — Servicios, runtime y offline-first sin regresión
- Mapear inicialización de `configureDependencies()`, `SyncSchedulerService.start()`, repositorios Drift y servicios remotos por experiencia.
- Identificar trabajo innecesario en Backoffice web y riesgos de inicialización; no deshabilitar ningún servicio hasta demostrar que el cambio es observacionalmente equivalente.
- Validar flujos offline POS, reintentos, idempotencia, pedidos pendientes, envío diferido y reconciliación. Las pruebas reales de mutación deben ocurrir fuera de producción.
- Revisar manejo de errores de red, expiración de sesiones, conectividad del navegador y recarga con pestañas abiertas.

**Salida:** matriz de inicialización y pruebas de regresión POS/offline.

### Fase 5 — Seguridad, datos y preparación multi-restaurante
- Documentar autenticación POS local vs admin remoto y restricciones de instalación/dispositivo.
- Auditar autorización de API/backend en cada operación administrativa; los guardas UI no protegen directamente los endpoints.
- Verificar aislamiento por restaurante/tenant (consultas, políticas RLS/servidor, escritura, reportes, archivos), incluyendo usuario de varios restaurantes **solo si está soportado**. Si falta soporte, clasificar como bloqueo comercial, no inventar multi-tenant.
- Validar CORS por origen, configuración de dominio, rate limit, expiración de tokens, política de permisos, TLS, logout, XSS y manejo de información sensible donde aplique a Flutter web y API.
- Gestionar secretos exclusivamente fuera del repositorio; no utilizar claves administrativas privilegiadas en el bundle web.
- Definir cuentas mínimas de operación, auditoría de acciones destructivas, privacidad, retención y backup/restore con responsables.

**Salida:** checklist de seguridad y clasificación de bloqueos P0/P1/P2.

### Fase 6 — Build web reproducible y configuración por entorno
- Conservar `tool/build_web_release.ps1` y verificar su uso real. Introducir parámetros de entorno **sin cambiar credenciales ni comportamiento del build de producción**.
- Definir entornos `dev`, `staging`, `production` con orígenes y recursos aislados y valores suministrados por el propietario; no asumir host de despliegue.
- Comprobar que la compilación final sirve `index.html`, `flutter_bootstrap.js`, `main.dart.js` o artefactos correspondientes, assets, fuentes, `sqlite3.wasm` y `drift_worker.js`; verificar MIME, caché y CORS si worker aplica.
- Revisar base href, recargas/direct links SPA, manejo 404, CSP y cabeceras de seguridad compatibles con Flutter/Drift, performance/LCP, tamaño del build y errores de consola.
- Verificar que ninguna credencial sensible termina en JS, sourcemaps públicos, logs o configuración cliente.
- Compilar APK release POS y Time Clock por separado, con firma válida y sin reemplazar identificadores existentes.

**Salida:** artefactos staging, comandos exactos registrados y checklist de contenido.

### Fase 7 — Dominio, DNS, HTTPS y hosting
**Prerequisitos pendientes:** FQDN adquirido, registrador/DNS, proveedor hosting, acceso a configurar zona DNS y servicio web. Son datos externos **no confirmados**.
- Elegir arquitectura final: p. ej. `backoffice.<dominio>` para app y `<dominio>` para marketing, **solo como propuesta**; confirmar dominio/canonical con propietario.
- Definir hosting capaz de servir Flutter SPA, HTTPS y assets WASM/worker; comparar opciones según coste, SLA, observabilidad y región.
- Publicar staging en subdominio separado, nunca sustituir producción sin gate.
- Configurar DNS únicamente con registros verificados por el proveedor; comprobar A/AAAA/CNAME, TTL, propagación, CAA, redirecciones apex/www y ausencia de conflictos de correo.
- Aprovisionar TLS, renovación, HTTP→HTTPS, cookies seguras, CSP/CORS y reglas de caché; evitar cachear HTML/bootstrap de forma que produzca clientes desincronizados.
- Alinear orígenes permitidos en backend/auth, redirect URLs, callback/logout y posible RLS. No deshabilitar controles para hacer funcionar CORS.
- Garantizar fallback SPA para rutas internas y compatibilidad con workers/wasm.
- Documentar responsable del dominio, expiración, renovación y recuperación de acceso sin guardar contraseñas.

**Salida:** staging en HTTPS con dominio validado y pruebas de acceso; plan cutover para producción.

### Fase 8 — QA integral, aceptación de negocio y rendimiento
- Smoke tests por experiencia + pruebas focalizadas por cambio; suite completa y `flutter analyze` antes de liberar.
- Matriz de roles: POS, admin, sin permiso, sesión caducada, desconectado. Verificar rechazo de rutas cruzadas.
- Navegación web: escritorio/tableta/teléfono, recarga, tabs, foco, retroceso, formularios con cambios pendientes, accesibilidad.
- Flujos administrativos **no destructivos** sobre staging: búsqueda/listados, detalles, impresión/PDF, filtros, roles, reportes; mutaciones aisladas con fixtures controlados.
- POS: venta, mesa, caja, impresión, offline/online y reconciliación en ambiente no productivo.
- Seguridad: revisión de tokens, RLS/tenant, exposición de endpoints, CORS/orígenes, encabezados y hallazgos críticos.
- QA operativa: pruebas de despliegue, redirecciones, consola, HTTP, errores, tiempos de respuesta, monitoreo, restauración desde backup.
- Evidencia: capturas, logs saneados, resultados automatizados y acta GO/NO-GO.

**Salida:** `MATRIZ_ACEPTACION.md` completada y firmada por propietario.

### Fase 9 — Publicación controlada en dominio
- Congelar release candidate y referencia Git exacta; generar artefactos reproducibles.
- Confirmar backups, acceso de reversión, DNS actual, dominio y certificados.
- Publicar primero staging, validar; realizar GO/NO-GO explícito.
- Desplegar hosting productivo, verificar HTTPS, DNS, rutas internas, autenticación remota, datos aislados, lectura/escritura autorizada y assets Drift.
- Monitorizar errores y rendimiento; hacer prueba de humo con usuario de control y sin datos sensibles.
- Mantener capacidad de volver a release anterior y restaurar DNS/config; definir responsables, disparadores de rollback y evidencia.
- No publicar ni fusionar automáticamente.

**Salida:** registro de release, URL definitiva, SHA, aprobaciones, estado de DNS/TLS, smoke y rollback.

### Fase 10 — Postpublicación y operación comercial
- Monitoreo de disponibilidad, errores cliente/API, vencimiento TLS/dominio, backups y costos.
- Procedimientos de soporte, gestión de incidentes, versionado, política de compatibilidad POS↔Backoffice y capacitación.
- Documentación de alta de restaurantes/dispositivos, permisos, recuperaciones y actualizaciones; marcar como pendiente lo no soportado.
- Ciclo de mantenimiento: ventanas, staging, aprobación release y verificaciones posteriores.

**Salida:** runbook operativo y traspaso a mantenimiento.

## 4. Secuencia de integración con PR #4

1. Esta documentación se publica en su propia rama/PR de solo documentación.
2. Crear rama técnica desde `main`; desarrollar primero contratos y pruebas de aislamiento.
3. Revisar PR #4 — no mezclar automáticamente estilos con cambios de autorización.
4. Rebasar/merge según estrategia de integración aprobada y resolver conflictos en staging.
5. Certificar conjuntamente Backoffice y POS; solo entonces pedir aprobación de merge y despliegue.

## 5. Gates de entrega — definición de listo

| Gate | Condición obligatoria |
|---|---|
| G0 Línea base | Inventario y snapshots revisados |
| G1 Arquitectura | Rutas clasificadas, sin autorización cruzada |
| G2 UX | 100% de pantallas administrativas inventariadas y revisadas; excepciones justificadas |
| G3 Operación | POS móvil/tableta y sync sin regresiones |
| G4 Seguridad | Sin P0/P1 pendientes: auth, tenant, credenciales, TLS, permisos |
| G5 Build | Web + Android reproducibles; assets y firma correctos |
| G6 Dominio | DNS, TLS, hosting, SPA y orígenes verificados |
| G7 QA | Matriz de aceptación completa; suite final y CI satisfactorios |
| G8 Release | Aprobación explícita, backup y rollback listos |
| G9 Soporte | Runbook y responsables definidos |

## 6. Matriz de riesgos y mitigación

- **R1 Datos de restaurantes cruzados (crítico):** pruebas de tenant/RLS en servidor y filtros; no liberar sin evidencia.
- **R2 POS afectado por widgets compartidos (alto):** snapshots/regresión móvil y tableta ante cambios de UI.
- **R3 Cambios en scheduler o cola (crítico):** prohibición de modificación implícita, pruebas offline/idempotencia en staging.
- **R4 Build web sin WASM/worker (alto):** smoke de red, MIME y recursos en hosting real.
- **R5 Dominio en DNS equivocado o correo interrumpido (alto):** inventario zona, cambios mínimos, TTL, rollback.
- **R6 Credenciales expuestas en frontend (crítico):** revisión del bundle, privilegios mínimos y backend.
- **R7 CI lento/repetitivo (medio):** pruebas selectivas durante desarrollo; CI final obligatorio antes de integrar.
- **R8 Firma Android de depuración para release (alto):** gate que valide identidad de firma en builds comerciales.

## 7. No objetivos de este proyecto

Crear módulos nuevos, desarrollar una API nueva, rediseñar la base de datos, implementar multiempresa si no existe, migrar Flutter a otro framework, rehacer POS o habilitar pagos nuevos. Hallazgos que requieran esas operaciones se documentan como proyectos separados con análisis de impacto.

## 8. Evidencia y trazabilidad

Cada tarea implementada debe registrar: archivo/ruta, impacto esperado, riesgo, prueba aplicada, evidencia, commit/PR y aprobación. Una fase no se cierra por apariencia ni por un solo check CI verde. El dominio y proveedor se rellenan cuando el propietario los confirme; hasta entonces son variables explícitamente pendientes.

**Documento complementario:** `PUBLICACION_DOMINIO_RUNBOOK.md` y `MATRIZ_ACEPTACION.md`.
