# Bitácora de avances y decisiones — SmooControl

**Propósito:** historial cronológico inmutable en la práctica (se agregan entradas; las anteriores no se sobrescriben). Refleja cambios documentales y, cuando inicie el proyecto, decisiones, bloqueos, pruebas y aprobaciones. El estado vigente se consulta en [SEGUIMIENTO_FASES.md](SEGUIMIENTO_FASES.md).

## 2026-11-03 — Preparación documental

- **Fase:** ninguna ejecutada.
- **Acción:** se creó el plan maestro end-to-end con fases F0–F10, runbook de publicación en dominio y matriz de aceptación; se añadió tablero verificable y esta bitácora.
- **Estado del programa:** NO INICIADO, 0/11 fases completas.
- **Repositorio:** rama documental `docs/plan-mejoras-backoffice-publicacion`, PR #5 en borrador. No se modificaron código, `main`, PR #4, DNS ni producción.
- **Evidencia:** archivos Markdown de `Plan Mejoras/`.
- **Bloqueos actuales:** ninguno para la documentación; F7 requerirá dominio exacto y acceso al proveedor DNS/hosting.
- **Próxima acción:** validar alcance documental y abrir F0 con línea base y registro de evidencias.
- **Aprobación de publicación:** NO CONCEDIDA.

## 2026-11-03 — Aclaración de alcance F0 por el propietario

- **Fase:** F0, ajuste documental de tareas ya definidas; no implica ejecución técnica.
- **Decisión:** el diseño Executive Ivory y la base visual existente ya están aprobados. No repetir elección de estética ni solicitar nueva aprobación de esa base.
- **Decisión:** Codex ejecuta pruebas, análisis y compilación en el entorno local, y el propietario revisa los resultados. No crear un segundo entorno de desarrollo ni sustituir esta validación por GitHub Actions repetitivos.
- **Salvaguarda:** pruebas con escritura solo mediante mocks, fixtures o datos aislados. El staging HTTPS de F7 se mantiene para validar el dominio antes de producción.
- **Avance F0:** dos definiciones reconocidas como cumplidas; quedan pendientes verificaciones de versiones, repositorio/worktrees/stashes y rollback.
- **Publicación:** no autorizada.

## 2026-11-03 — Avance autónomo F1 y F2

- **F1:** se generó `MATRIZ_EXPERIENCIAS.md` con las 47 rutas declaradas en `AppRoutes`, clasificación POS/Backoffice y permisos; `INVENTARIO_PRESENTACION.md` registra 222 archivos de presentación en 24 módulos para revisión de dependencias indirectas.
- **F2:** PR #6 (borrador), rama `develop/experience-isolation`, HEAD `853f9091214afdaf9e0df284dcfcaa819bb4db74`. Se agregó contrato de experiencia, guard de rutas nombradas y pruebas unitarias focalizadas.
- **Resultado:** revisión remota implementada, **no compilada ni validada localmente**.
- **Interrupción requerida:** Codex debe sincronizar en worktree separado, ejecutar análisis/pruebas y smoke de rutas con sesión POS, admin y Time Clock. No modificar datos productivos ni fusionar.
- **F0:** aprobación visual y estrategia QA local previamente confirmadas; comprobaciones de entorno local se recogen en la intervención de Codex, sin rehacer diseño.
- **Próxima acción:** recibir resultados concretos de Codex y continuar F2/F3 automáticamente.
- **Publicación:** no autorizada.

## 2026-11-03 — Codex validó PR #6; avisos de lint corregidos

- **Evidencia Codex:** worktree local `SmooControl-experience-isolation`, SHA `853f9091`, limpio y `main` intacta; 3/3 pruebas aprobadas.
- **Análisis:** 4 avisos de lint y cero errores de compilación reportados; corregidos en la misma PR #6 (HEAD `7c88263031122cc62ca20a72d88ae6aca1bfa604`).
- **Cobertura pendiente:** test/validación de entrada `TimeClockGate`; no se declara completa F2 sin la nueva validación.
- **Siguiente intervención Codex:** fast-forward seguro de worktree aislado al nuevo HEAD y repetir `flutter analyze` y test focalizado. No tocar `main` ni producción.
- **Estado:** F2 EN_VALIDACIÓN, no publicada.

## 2026-11-03 — Segundo control Codex aprobado y avance F3

- **F2:** Codex confirmó worktree `develop/experience-isolation` al SHA `7c882630`, limpio, `main` intacta, `flutter analyze` sin issues y tests de rutas 3/3.
- **Estado F2:** validación de código focalizado superada; queda cobertura de entrada real de Time Clock y smoke de navegación/roles previa a integrar, sin necesidad de repetir aprobación de diseño.
- **F3:** comenzó revisión estática de PR #4 (7 archivos de presentación), verificando cambios de acciones contextuales en ventas, caja, inventario, auditoría y vacaciones, y adaptación de diálogos de planilla; PR no fusionada.
- **Próximo avance:** consolidar cobertura UX de todos los módulos, preservar POS y generar validación local de integración de PR #4 + aislamiento F2 antes de solicitar revisión visual.
- **Producción:** sin cambios, despliegue no autorizado.

## 2026-11-03 — Integración real preparada, checkpoint Codex

- **Motivo:** se detectó que la revisión de F3 se había detenido sin desarrollar una integración verificable; corregido el flujo para continuar hasta una dependencia local real.
- **Trabajo realizado:** creada rama `develop/backoffice-stabilization-integration`, con base exacta `develop/experience-isolation` SHA `7c882630`; integrados los blobs correspondientes a los 7 archivos de PR #4 sin alterar otras rutas.
- **Resultado:** PR #7 borrador; HEAD `94846f3934963f9e5c57e872dd0e22a135605b79`. Comparación contra `main`: 10 archivos modificados (3 de F2, 7 de F3).
- **Control:** PR #4, PR #6, `main`, POS de producción y entorno local no modificados.
- **Riesgos:** integración no compilada; UX todavía no es integral y F2 conserva pendiente cobertura de entrada de Time Clock.
- **Punto donde Codex sí es necesario:** build/análisis y tests de la rama combinada en worktree local independiente, sin merge/despliegue. Tras la evidencia continuará la ejecución de F3/F4.
- **Aprobación:** no se solicita revisión visual todavía; publicación no autorizada.

## 2026-11-03 — PR #7 verificada por Codex en local

- **Rama:** `develop/backoffice-stabilization-integration`, SHA `94846f3934963f9e5c57e872dd0e22a135605b79`, worktree limpio; 11 stashes preservados y `main` intacta.
- **Verificación:** `flutter analyze` sin issues; **44/44 pruebas** aprobadas, build web release oficial correcto y recursos Drift/SQLite presentes.
- **Observaciones:** warning no fatal hit-test POS durante acción Exit, revisar en siguiente ciclo de QA; prueba widget de entrada Time Clock aún pendiente.
- **F3:** integración base técnicamente validada, pero aún no alcanza cobertura visual integral del Backoffice; continuar inspección/implementación restante antes de convocar al propietario.
- **Producción:** sin merge ni despliegue.

## 2026-11-03 — Ampliación real de F3 después de QA local

- **Codex:** PR #7 inicial SHA `94846f39` validada: analyze sin issues, 44/44 pruebas OK y build web oficial con recursos Drift/SQLite.
- **Cambios posteriores:** Marcadas administra selección contextual Editar/Eliminar sin columna Acciones, preservando modo reporte de solo lectura. Puestos ahora tiene tabla profesional, búsqueda y selección para Editar, conservando operaciones existentes.
- **Branch/PR:** `develop/backoffice-stabilization-integration`, PR #7, nuevo HEAD `20c0e2ea9d06f02fed09147c1bfc76ffd0e65d80`.
- **Estado:** estos cambios nuevos NO están validados en Codex todavía. Se requiere nuevo fast-forward y análisis/pruebas dirigidas.
- **Pendiente F3:** UX de submódulos administrativos restantes, revisión visual final del propietario, más pruebas Time Clock.
- **Límite:** sin merge ni producción; modificación exclusiva de presentación.

## Plantilla para nuevos eventos

```text
### AAAA-MM-DD HH:mm (America/Managua) — <título>
- Fase/tarea:
- Estado antes → después:
- Resultado:
- Archivos / PR / SHA:
- Pruebas y evidencia:
- Bloqueos / severidad / responsable:
- Próxima acción:
- Aprobación (nombre/fecha), si corresponde:
```

**Política:** si un estado o evidencia anterior fue incorrecto, agregar una rectificación fechada; nunca borrar la trazabilidad de decisiones.
