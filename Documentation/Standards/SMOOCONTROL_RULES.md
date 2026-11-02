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
| SMO-008 | Los cambios de interfaz del Backoffice se realizan **directamente sobre las pantallas operativas autenticadas y sus componentes reutilizables**. No introducir rutas de demostración, pantallas aisladas con registros ilustrativos ni prototipos alternativos salvo solicitud explícita del propietario. El QA debe distinguir datos reales de prueba de datos ficticios y mantener permisos y persistencia existentes. |
| SMO-009 | En **catálogos administrativos del Backoffice**, seleccionar una fila para operar sobre ella mediante una **botonera superior fija**: «Nuevo» y todas las operaciones reales («Editar», «Inactivar», «Quitar nivel», etc.) con etiquetas visibles, sin columna repetitiva «Acciones» ni menús «Más». Acciones que dependen de selección deshabilitadas hasta elegir un registro y cuando el estado/permisos no las permiten. Resaltar selección, permitir teclado y pantalla compacta; limpiar selección al filtrar, paginar o cuando el registro deje de estar disponible. Preservar confirmaciones y operaciones originales. **No aplica a modo App/POS ni modo Tableta**; las listas transaccionales conservan acciones apropiadas al dominio hasta su revisión específica. |

## Medición de SMO-001
- Para archivos nuevos o modificados de código mantenido a mano, el límite provisional se mide por **líneas físicas completas**.
- No dividir métodos o clases arbitrariamente sólo para alcanzar 300; aplicar responsabilidad única, módulos y cohesión.
- Identificar archivos legados o generados que exceden el límite, sin reescribirlos de manera riesgosa y automática.
- Cuando haya conflicto técnico excepcional, documentar la necesidad y solicitar aprobación antes de asumir una excepción permanente.

## Adopción
El `AGENTS.md` de SmooControl debe referenciar una revisión exacta del estándar central disponible localmente o a través de una conexión accesible. No duplicar manualmente normas centrales con modificaciones no sincronizadas.
