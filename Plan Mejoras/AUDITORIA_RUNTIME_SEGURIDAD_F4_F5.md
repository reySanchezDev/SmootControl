# F4/F5 — Auditoría de ejecución y configuración de entorno (sin cambios de negocio)

**Fecha:** 2026-11-03. **Referencia:** lectura de código `main` (`c6680eb6`); los cambios F3/PR #7 no modifican estos archivos. **Estado:** análisis estático; no certifica backend ni datos reales.

## Hechos verificables

| Área | Evidencia | Consecuencia y verificación necesaria |
|---|---|---|
| Arranque | `lib/main.dart` ejecuta `configureDependencies()`, luego `SyncSchedulerService.start()`, y por último `runApp()` | Scheduler se inicia antes de resolución de sesión/experiencia, también en web estándar. Auditar impacto y posibles reintentos, **no alterar** sin equivalencia probada |
| Inyección DI | `configureDependencies()` registra Core, Catálogo, Operaciones, Settings/Admin, Sales/Sync, Auth y POS | Los servicios están registrados globalmente pero varios son lazy. Registrar != ejecutar. Aislamiento por instancia/ciclo de vida pendiente de pruebas |
| Sincronización | `SyncSchedulerService.start()` llama `refresh(runStartupSync: true)` y agenda temporizador cuando `autoSyncEnabled`; dispara `runNow()` en arranque si `syncOnStartup` | Revisar configuración local efectiva, cola y restauración; no eliminar timers ni cambiar criterios de envío sin QA offline |
| Configuración remota | `SupabaseAppConfig` toma URL y publishable key de `String.fromEnvironment` | Publishable key es de cliente; **no** insertar secretos service-role en build. Probar permisos backend reales |
| Restaurante | `CurrentRestaurantService` usa `SMOO_RESTAURANT_ID` como constante de compilación | **Riesgo comercial a resolver:** build web dirigido a un restaurante fijo; verificar diseño de tenant y login antes de exponer dominio a varios restaurantes |
| Autenticación | `AuthGate` envía sesión POS a `PosPage` y otra a `BackofficeHomePage` | Mantener diferenciación; backend debe verificar autorización de operaciones |
| Token admin | `CurrentRemoteSessionService` guarda token en memoria, invalida cerca de vencimiento | Verificar refresh/relogin, recarga del navegador, expiración y recuperación de errores. No afirmar persistencia de sesión |
| Backoffice online | `AdminOnlineGuard` comprueba token y `connectivity_plus` | Conectividad detectada no equivale a API disponible; verificar respuestas de backend y errores de red |

## Riesgos y acciones verificables (sin cambiar código aún)

### R-F4-1: Scheduler global (alto por potencial impacto de negocio)
- [x] Confirmar orden de inicialización y disparadores del scheduler en código.
- [ ] Revisar configuración efectiva local y transacciones en cola por experiencia.
- [ ] Comparar comportamiento `main` y PR #7 en POS online/offline con datos de prueba.
- [ ] Determinar si se requiere aislamiento runtime; cambio de inicialización **solo** con tests de equivalencia.

### R-F5-1: Restaurante de compilación fijo (alto para comercialización multi-cliente)
- [x] Confirmar que `SMOO_RESTAURANT_ID` se toma del entorno de build.
- [ ] Verificar que el backend limite cada operación al restaurante permitido por usuario, no solo por parámetro.
- [ ] Confirmar si el dominio será para **un restaurante** o **varios restaurantes** (no asumir SaaS multi-tenant).
- [ ] Si es multi-tenant, diseñar resolución autorizada de restaurante por sesión, sin alterar el modelo de negocio durante este plan salvo autorización independiente.

### R-F5-2: Permisos y sesión remota (alto)
- [x] Confirmar token admin en memoria y guardas UI.
- [ ] Verificar políticas servidor/RLS/roles para lectura y escritura.
- [ ] Confirmar error de API al cambiar permisos/tenant y logout/expiración.

## Gate de avance

Estos hallazgos **no bloquean las mejoras puramente visuales de F3** pero **bloquean declarar listo el Backoffice público para dominio comercial** sin pruebas reales y decisión de alcance de tenant. No cambiar datos/productivo para investigarlos. Las verificaciones operativas requerirán Codex en local y acceso autorizado a staging/no producción.

**Acción siguiente automática:** cerrar trazabilidad de F3 en PR #7 y ejecutar la verificación local de pruebas pendiente; preparar validación de comportamiento offline/servidor cuando corresponda.
