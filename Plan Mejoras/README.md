# Plan Mejoras — SmooControl

Documentación de estabilización arquitectónica, unificación de Backoffice y preparación de publicación en dominio propio.

## Documentos

**Para conocer el estado actual y continuar sin perder el hilo, empezar por [SEGUIMIENTO_FASES.md](SEGUIMIENTO_FASES.md).**

1. [Plan maestro end-to-end](PLAN_MAESTRO_END_TO_END.md) — fases 0–10, arquitectura, alcance, seguridad, UX, construcción, hosting, DNS, release y operación.
2. [Runbook de publicación del dominio](PUBLICACION_DOMINIO_RUNBOOK.md) — decisiones, pasos verificables, DNS/TLS, staging, producción, rollback.
3. [Matriz de aceptación](MATRIZ_ACEPTACION.md) — checklist con criterios, evidencias y autorización de salida.
4. [Seguimiento fase a fase](SEGUIMIENTO_FASES.md) — tablero F0–F10, tareas, estados, bloqueos, criterios de cierre y próxima acción.
5. [Bitácora de avances](BITACORA_AVANCES.md) — historial cronológico de cambios, evidencias, bloqueos, correcciones y decisiones.

**Estado:** planes documentados, ejecución pendiente. Ningún dominio, hosting o servicio ha sido configurado. Se mantienen intactos `main`, producción y PR #4.

## Reglas de seguimiento

- El tablero es la fuente única de estado: una fase activa a la vez, salvo excepción documentada.
- En cada sesión se actualizan avance, evidencia, problemas, SHA/PR y siguiente acción.
- Las fases solo se cierran con sus criterios de aceptación verificados y aprobación registrada.
- El programa concluye tras F10 y la publicación validada en dominio propio; ninguna ejecución parcial implica producción lista.

## Reglas de ejecución

- No iniciar ejecución sin aprobar alcance/ambiente.
- El Backoffice es una experiencia funcional y móvil/tableta son layouts del POS, no roles ni aplicaciones nuevas.
- No alterar ventas, pagos, caja, inventario, datos, colas, ni sincronización.
- Cambios en PR y rama propios; no tocar release/producción sin autorización.
- Codex se encarga de pruebas y build local; la aprobación de liberación es del propietario.
