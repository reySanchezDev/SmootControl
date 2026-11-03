# Tablero de seguimiento — estabilización y publicación SmooControl

**Estado del programa:** EN_CURSO  
**Fase activa:** F3 (corrección de tests POS preexistentes pendiente de validación Codex)  
**Fuente de alcance:** [Plan maestro](PLAN_MAESTRO_END_TO_END.md)  
**Criterios finales:** [Matriz de aceptación](MATRIZ_ACEPTACION.md)  
**Despliegue:** [Runbook dominio](PUBLICACION_DOMINIO_RUNBOOK.md)  
**Última actualización:** 2026-11-03 (Codex reporta analyze limpio y 93/93 pruebas POS; discrepancia con los 102 casos previos pendiente de conciliar. Tres archivos locales solo formateados sin commit. F4/F5 auditados estáticamente).

> **Fuente única de verdad:** este tablero controla qué fase está abierta y cuáles están cerradas. No se marca una tarea, fase o gate como terminada por un commit, una PR o un CI exitoso sin evidencia y verificación de sus criterios.

## 1. Estados y reglas

Estados admitidos para cada fase:

- `PENDIENTE`: no iniciada.
- `EN_CURSO`: tareas iniciadas, evidencia parcial registrada.
- `BLOQUEADA`: impedimento identificado con responsable y siguiente acción.
- `EN_VALIDACION`: implementación completa, esperando verificación y aprobación.
- `COMPLETADA`: criterios de cierre verificados y evidenciados, aprobación registrada.
- `REABIERTA`: se detectó regresión tras el cierre, con motivo y nueva validación.

**Flujo:** PENDIENTE → EN_CURSO → EN_VALIDACION → COMPLETADA; cualquier fase puede pasar a BLOQUEADA y reanudarse, o REABIERTA si falla una condición previamente aprobada.

**Regla de avance:** por defecto se trabaja en **una línea principal de ejecución a la vez**, avanzando de manera automática. La siguiente inicia automáticamente cuando su dependencia lógica esté resuelta, sin solicitar confirmaciones rutinarias; la verificación local pendiente se registra para el punto obligatorio de Codex. No bloquear auditorías documentales por trabajo local independiente. Las fases futuras pueden planificarse sin considerarse iniciadas.

**Regla de cierre:** toda fase necesita (1) tareas completas o N/A justificado, (2) pruebas acordes al riesgo, (3) evidencia trazable, (4) cero bloqueos críticos abiertos, (5) aprobación del responsable. La publicación exige autorización expresa del propietario, no inferida.

**Regla de actualización:** en cada sesión de trabajo actualizar tabla, checklist, evidencias/commit, bloqueos, siguiente acción y bitácora. No alterar historial: agregar un nuevo registro en [Bitácora](BITACORA_AVANCES.md).

## 2. Estado general

| Fase | Nombre | Estado | Dependencia previa | Resultado comprobable |
|---|---|---|---|---|
| F0 | Línea base y protección del entorno | EN_VALIDACION (local Codex pendiente) | Ninguna | Snapshot y rollback confirmados |
| F1 | Inventario completo de experiencias | EN_CURSO | F0 | Matriz de rutas y componentes 100% clasificados |
| F2 | Contratos de experiencia y autorización | EN_VALIDACION (analyze y tests OK; Time Clock pendiente) | F1 | Acceso por sesión/experiencia/permiso validado |
| F3 | UX integral Backoffice Executive Ivory | EN_CURSO | F2 | Todas las pantallas auditadas y aceptadas |
| F4 | Runtime, servicios y sincronización segura | PENDIENTE | F1, F2 | Regresión POS/offline superada |
| F5 | Seguridad y aislamiento por restaurante | PENDIENTE | F2, F4 | Sin bloqueos P0/P1 de seguridad |
| F6 | Build web y Android reproducibles | PENDIENTE | F3, F4, F5 | Builds íntegros y verificables |
| F7 | Hosting, staging, DNS y HTTPS | PENDIENTE | F5, F6 | Staging HTTPS validado |
| F8 | QA integral y aceptación comercial | PENDIENTE | F3–F7 | Matriz QA y GO/NO-GO completos |
| F9 | Publicación controlada en dominio | PENDIENTE | F8 y aprobación expresa | Release productivo + rollback preparado |
| F10 | Operación y soporte postpublicación | PENDIENTE | F9 | Monitoreo, soporte y runbook entregados |

**Avance:** 0 de 11 fases completadas. Este porcentaje es **administrativo**, no estimación de esfuerzo. Una fase no equivale a una onceava parte del trabajo.

## 3. Protocolo de ejecución sin interrupciones

- ChatGPT avanza automáticamente entre tareas y fases remotas sobre el plan. No pedir autorización de rutina ni enviar reportes por cada archivo.
- **Interrupciones permitidas:** (a) Codex requiere compilar/probar/sincronizar en el local; (b) propietario debe evaluar el resultado visual; (c) decisión externa imprescindible (dominio, DNS, hosting, aprobación explícita de merge/despliegue o acción irreversible).
- En cada interrupción enviar solo: **estado**, **qué debe hacer cada parte**, y **qué sigue**. Los detalles técnicos y evidencia quedan en los documentos del repo.
- F0 no se vuelve a discutir visualmente: Executive Ivory ya aprobado; Codex puede cerrar inventario local/worktrees y validación de rollback al siguiente punto de control sin bloquear la revisión de código remoto.
- No marcar controles locales como verificados si Codex aún no ha presentado evidencia; registrar pendientes sin detener el resto del trabajo.

**Punto de intervención Codex (F2):** únicamente validar PR #6 en worktree independiente; ejecutar `flutter analyze` y `flutter test test/core/navigation/app_route_experience_test.dart`, luego smoke de rutas y de entradas existentes. No fusionar, no realizar reset destructivo, no modificar producción. Si existen errores reportarlos con líneas y archivos, sin alterar la lógica de negocio.

**Revisión F4/F5 paralela y no invasiva:** `AUDITORIA_RUNTIME_SEGURIDAD_F4_F5.md` documenta scheduler global y restaurante fijado por build; no autoriza cambios de negocio ni publicar como multiempresa sin pruebas de backend.

## 4. Seguimiento detallado por fase

### F0 — Línea base y protección del entorno

**Estado:** EN_VALIDACION (solo verificaciones técnicas locales pendientes) · **Responsable técnico:** ChatGPT/Codex · **Aprobación:** propietario.

- [ ] Registrar HEAD de `main`, PR #4, ramas y worktrees.
- [ ] Preservar y documentar stashes y cambios locales.
- [ ] Identificar versión Flutter/Dart/Gradle y configuración de entornos.
- [x] Reconocer como línea base visual aprobada por el propietario el diseño Executive Ivory y los patrones previamente aceptados; no rediseñar ni solicitar nueva aprobación de esa base. La verificación de que las pantallas lo respetan corresponde a F3.
- [x] Establecer flujo de validación: pruebas y compilaciones locales con Codex; revisión visual y aceptación por el propietario. No crear un entorno remoto de QA por defecto. Para operaciones que escriban datos, usar fixtures/mocks o datos aislados y nunca producción; cualquier excepción se documentará antes de ejecutarse.
- [ ] Definir estrategia y verificar reversión de cambios Git.

**Cierre:** línea base reproducible, evidencias guardadas, ningún cambio productivo.
**Evidencia:** confirmación explícita del propietario en la conversación del 2026-11-03 para base visual y validación local; pendiente consignar HEAD, worktrees, versiones y rollback. **Bloqueos:** ninguno registrado · **Siguiente acción:** completar verificaciones técnicas restantes de F0 sin repetir aprobaciones ya otorgadas.

### F1 — Inventario completo de experiencias

**Estado:** EN_CURSO · **Responsable:** ChatGPT.

- [x] Inventariar todas las 47 rutas declaradas en AppRoutes y los destinos sidebar; [ ] completar subrutas, tabs, detalles y diálogos indirectos.
- [x] Clasificar las rutas declaradas como Backoffice/POS y la entrada especial Time Clock; [ ] completar pantallas auxiliares indirectas.
- [x] Asociar permisos declarados y requisitos de conectividad por ruta en `MATRIZ_EXPERIENCIAS.md`; [ ] revisar excepciones en tiempo de ejecución.
- [x] Identificar componentes centrales, UI compartida y scheduler de riesgo; [ ] completar mapa de dependencias indirectas.
- [ ] Registrar exclusiones y excepciones justificadas.
- [x] Publicar `MATRIZ_EXPERIENCIAS.md`; [ ] cerrar cobertura de subpantallas y navegación dinámica.

**Cierre:** 100% de rutas navegables clasificadas; dependencias de riesgo documentadas.
**Evidencia:** `MATRIZ_EXPERIENCIAS.md`, HEAD del documento `d835c010`; **Bloqueos:** ninguno para revisión remota · **Siguiente acción:** completar rutas indirectas y preparar F2.

### F2 — Contratos de experiencia y autorización

**Estado:** EN_VALIDACION (código en PR #6; no certificado) · **Responsable:** ChatGPT, Codex para validación.

- [x] Definir contrato mínimo `AppRouteExperience` y `SmooExperience` en PR #6 sin duplicar router/BLoC.
- [ ] Verificar `AuthGate`, tipos de sesión y experiencia.
- [x] Declarar rutas por experiencia, preservando permisos existentes; [ ] comprobar que no falta ninguna ruta real.
- [x] Implementar guard de experiencia para rutas nombradas y fallback seguro en PR #6; [ ] verificar pruebas locales.
- [ ] Verificar expiración de sesión, logout y cambios de permisos.
- [ ] Validar con Codex `flutter analyze`, test de contrato y smoke POS/Backoffice/TimeClock (sin datos productivos).

**Cierre:** pruebas de roles/rutas y navegación aprobadas; negocio intacto.
**Evidencia:** PR #6 (`7c882630`), Codex verificó fast-forward limpio, `flutter analyze` sin issues y 3/3 pruebas; **pendiente:** prueba de entrada Time Clock y rutas indirectas. **Siguiente acción:** finalizar smoke de entrada con Codex en punto de integración, sin repetir tests ya certificados.

### F3 — UX integral Backoffice Executive Ivory

**Estado:** EN_CURSO · **Responsable:** ChatGPT/Codex; aceptación visual: propietario.

- [ ] Auditar todas las pantallas administrativas y subpantallas; revisión inicial de PR #4 documentada en `AUDITORIA_UX_F3.md`.
- [ ] Unificar componentes, colores, fuentes, densidad y textos UX.
- [x] Extender selección y acciones explícitas a Marcadas y Puestos en PR #7; [ ] completar revisión de los demás módulos, filtros, scroll, encabezados y acciones etiquetadas.
- [ ] Eliminar patrones ambiguos de columna `Acciones` / `Más` según diseño aprobado.
- [ ] Ajustar diálogos desktop frente a vistas compactas.
- [ ] Verificar teclado, accesibilidad, zoom, estados vacíos y errores.
- [x] Identificar los 7 archivos de presentación de PR #4 y verificar que no modifica lógica de dominio/BD; [ ] revisar la totalidad de la UX, las dependencias y realizar validación de integración antes de decidir merge.
- [ ] Completar evidencias por pantalla en 390×844, 768×1024, 1366×768 y 1920×1080.

**Cierre:** matriz de pantallas y regresión POS aprobadas; excepciones documentadas. **Checkpoint Codex:** consolidar y publicar exclusivamente los tres formatos locales de tests POS sin modificar semántica; verificar SHA/limpieza, analizar la diferencia 93 vs 102 tests usando los comandos exactos y completar la validación relevante. Mantener main, stashes, 8080/8081 y producción intactos; aún no es aprobación visual final.
**Evidencia:** PENDIENTE · **Bloqueos:** ninguno registrado · **Siguiente acción:** pendiente de F2.

### F4 — Runtime, servicios y sincronización

**Estado:** PENDIENTE · **Responsable:** ChatGPT/Codex.

- [ ] Mapear inicialización de dependencias por experiencia.
- [ ] Auditar ciclo de vida de `SyncSchedulerService` en web/Android.
- [ ] Demostrar ausencia de efectos laterales de servicios compartidos.
- [ ] Verificar persistencia, offline, cola, reintentos e idempotencia POS en pruebas aisladas.
- [ ] Verificar expiración de sesión administrativa y errores de conectividad.
- [ ] Conservar contratos y payloads sin cambios.

**Cierre:** equivalencia funcional documentada y pruebas POS/offline aprobadas.
**Evidencia:** PENDIENTE · **Bloqueos:** ninguno registrado · **Siguiente acción:** pendiente de F1/F2.

### F5 — Seguridad, autorización backend y tenants

**Estado:** PENDIENTE · **Responsable:** revisión técnica; aprobación de riesgos: propietario.

- [ ] Verificar autorización real de APIs (no solo guardas UI).
- [ ] Validar aislamiento por restaurante/tenant en lectura y escritura.
- [ ] Revisar credenciales, tokens, datos sensibles y bundle web.
- [ ] Revisar CORS, redirect URLs, sesión, expiración y HTTPS.
- [ ] Evaluar políticas RLS, privilegios mínimos y operaciones destructivas.
- [ ] Clasificar hallazgos P0/P1/P2 con remediación y evidencia.

**Cierre:** cero P0/P1 abiertos; riesgos residuales aprobados explícitamente.
**Evidencia:** PENDIENTE · **Bloqueos:** ninguno registrado · **Siguiente acción:** pendiente de F2/F4.

### F6 — Builds reproducibles y distribución

**Estado:** PENDIENTE · **Responsable:** Codex; arquitectura: ChatGPT.

- [ ] Registrar comandos Flutter web y Android.
- [ ] Verificar configuración de staging y producción.
- [ ] Comprobar WASM, Drift worker, bootstrap, fuentes y recursos estáticos.
- [ ] Verificar rutas SPA, base href, caché y cabeceras compatibles.
- [ ] Validar compilación POS Android release con firma correcta.
- [ ] Validar flavor Time Clock y preservar `applicationId`.
- [ ] Documentar commits/versiones/checksums.

**Cierre:** artefactos reproducibles, sin credenciales privilegiadas y smoke satisfactorio.
**Evidencia:** PENDIENTE · **Bloqueos:** ninguno registrado · **Siguiente acción:** pendiente de F3–F5.

### F7 — Hosting, staging, dominio, DNS y HTTPS

**Estado:** PENDIENTE · **Responsable:** ChatGPT/Codex; acceso y aprobación: propietario.

- [ ] Confirmar FQDN exacto comprado, DNS y registrador.
- [ ] Seleccionar hosting y origen canonical del Backoffice.
- [ ] Crear staging aislado con datos de ensayo.
- [ ] Configurar DNS sin afectar MX/SPF/DKIM/DMARC existentes.
- [ ] Verificar certificados TLS, renovación, redirección HTTPS.
- [ ] Configurar fallback SPA, caché, WASM/worker, CORS y callbacks auth.
- [ ] Ejecutar smoke real en el FQDN de staging.

**Cierre:** staging accesible con HTTPS, autenticación y assets operativos.
**Evidencia:** PENDIENTE · **Bloqueo previsible, no confirmado:** faltan datos del dominio y hosting · **Siguiente acción:** obtener datos antes de F7.

### F8 — QA integral y aceptación

**Estado:** PENDIENTE · **Responsable:** Codex/QA; aprobación: propietario.

- [ ] Análisis estático limpio respecto a línea base.
- [ ] Pruebas focalizadas y suite integral pertinente aprobadas.
- [ ] GitHub Actions final aprobado.
- [ ] Matriz completa de escenarios Backoffice, POS y Time Clock.
- [ ] Pruebas de seguridad, tenant, navegadores, accesibilidad, rendimiento.
- [ ] Ensayo de backups y rollback.
- [ ] Completar `MATRIZ_ACEPTACION.md` y acta GO/NO-GO.

**Cierre:** evidencias y autorización de release; ningún bloqueo crítico.
**Evidencia:** PENDIENTE · **Bloqueos:** ninguno registrado · **Siguiente acción:** pendiente de F3–F7.

### F9 — Publicación controlada del Backoffice

**Estado:** PENDIENTE · **Responsable:** despliegue técnico; autorización: propietario.

- [ ] Aprobar explícitamente dominio, SHA y versión candidata.
- [ ] Congelar artefacto validado, backup y rollback.
- [ ] Configurar hosting y dominio final según runbook.
- [ ] Validar DNS, TLS, login, roles, SPA, assets y API.
- [ ] Registrar monitoreo inmediato, errores y rollback disponible.
- [ ] Documentar URL productiva, hora y resultado del despliegue.

**Cierre:** sitio operativo y aprobado, sin incidentes P0/P1.
**Evidencia:** PENDIENTE · **Bloqueos:** ninguno registrado · **Siguiente acción:** pendiente de F8 y permiso explícito.

### F10 — Estabilización pospublicación y operación

**Estado:** PENDIENTE · **Responsable:** operación/soporte; aceptación: propietario.

- [ ] Configurar vigilancia de disponibilidad, TLS y errores.
- [ ] Registrar gestión de incidentes y procedimiento de recuperación.
- [ ] Documentar actualización compatible POS ↔ Backoffice.
- [ ] Definir backup, restauración, renovación y responsables.
- [ ] Entregar guía de alta de clientes/dispositivos y soporte.
- [ ] Registrar cierre de programa y pendientes evolutivos.

**Cierre:** runbook operativo, responsables designados y aceptación final.
**Evidencia:** PENDIENTE · **Bloqueos:** ninguno registrado · **Siguiente acción:** pendiente de F9.

## 4. Ficha obligatoria de actualización

Copiar esta ficha en la sección de bitácora para cada avance relevante:

```text
Fecha/hora (America/Managua):
Fase / tarea:
Estado anterior → nuevo:
Resultado concreto:
Rutas/archivos modificados:
Commit/PR:
Prueba realizada + resultado:
Evidencia (ruta/enlace):
Bloqueos (severidad, responsable, acción):
Siguiente acción única:
Aprobación (si aplica):
```

## 5. Condición de finalización del programa

**No se declara finalizado** hasta que F0–F10 estén COMpletadas con evidencia, el Backoffice opere bajo el **dominio final aprobado** con HTTPS y controles de seguridad, POS Android móvil/tableta y Time Clock no presenten regresiones, se haya validado rollback y el propietario firme el cierre. Si una fase completada falla posteriormente se marca `REABIERTA` y el estado general vuelve a EN_CURSO.

**Nota:** ningún porcentaje de avance reemplaza los gates de seguridad, dominio y producción.
