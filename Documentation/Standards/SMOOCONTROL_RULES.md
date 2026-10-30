# SmooControl — Normas particulares del producto

**Alcance:** desarrollo y mantenimiento de SmooControl, especialmente Backoffice V2. Complementan el estándar universal.

| ID | Regla |
|---|---|
| SMO-001 | Máximo **300 líneas físicas** por archivo de código fuente escrito/mantenido manualmente. Extraer responsabilidades cohesionadas, sin fragmentación artificial. Archivos generados y legado requieren tratamiento documentado, no refactorización ciega. |
| SMO-002 | Backoffice administrativo web-first; conservar independencia funcional del POS. |
| SMO-003 | Multipestaña administrativa, sidebar contraíble e Inicio cerrable. |
| SMO-004 | Catálogos/datos maestros primero; operaciones derivadas después; Reportes como módulo propio, sujeto a rutas y permisos reales. |
| SMO-005 | Métricas reales y acceso efectivo por rol; permisos también en servicios/repositorios, no sólo en la interfaz. |
| SMO-006 | V2 en `develop/backoffice-v2` hasta aprobación explícita; no modificar `main` ni datos de producción por cambios de UX. |
| SMO-007 | Executive Ivory mediante componentes/tokens compartidos, sin alterar el tema del POS. |

## Medición de SMO-001
- Para archivos nuevos o modificados de código mantenido a mano, el límite provisional se mide por **líneas físicas completas**.
- No dividir métodos o clases arbitrariamente sólo para alcanzar 300; aplicar responsabilidad única, módulos y cohesión.
- Identificar archivos legados o generados que exceden el límite, sin reescribirlos de manera riesgosa y automática.
- Cuando haya conflicto técnico excepcional, documentar la necesidad y solicitar aprobación antes de asumir una excepción permanente.

## Adopción
El `AGENTS.md` de SmooControl debe referenciar una revisión exacta del estándar central disponible localmente o a través de una conexión accesible. No duplicar manualmente normas centrales con modificaciones no sincronizadas.
