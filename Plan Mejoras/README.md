# Plan Mejoras — SmooControl

Documentación de estabilización arquitectónica, unificación de Backoffice y preparación de publicación en dominio propio.

## Documentos

1. [Plan maestro end-to-end](PLAN_MAESTRO_END_TO_END.md) — fases 0–10, arquitectura, alcance, seguridad, UX, construcción, hosting, DNS, release y operación.
2. [Runbook de publicación del dominio](PUBLICACION_DOMINIO_RUNBOOK.md) — decisiones, pasos verificables, DNS/TLS, staging, producción, rollback.
3. [Matriz de aceptación](MATRIZ_ACEPTACION.md) — checklist con criterios, evidencias y autorización de salida.

**Estado:** planes documentados, ejecución pendiente. Ningún dominio, hosting o servicio ha sido configurado. Se mantienen intactos `main`, producción y PR #4.

## Reglas de ejecución

- No iniciar ejecución sin aprobar alcance/ambiente.
- El Backoffice es una experiencia funcional y móvil/tableta son layouts del POS, no roles ni aplicaciones nuevas.
- No alterar ventas, pagos, caja, inventario, datos, colas, ni sincronización.
- Cambios en PR y rama propios; no tocar release/producción sin autorización.
- Codex se encarga de pruebas y build local; la aprobación de liberación es del propietario.
