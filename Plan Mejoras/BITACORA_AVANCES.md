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
