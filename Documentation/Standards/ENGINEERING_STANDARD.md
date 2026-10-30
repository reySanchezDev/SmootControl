# Ingeniería — Estándar transversal Quantix

**Estado:** versión inicial; los criterios no ratificados se mantienen como propuestas, no obligaciones inventadas.

## Reglas confirmadas

| ID | Regla |
|---|---|
| ENG-001 | Revisar y reutilizar componentes, servicios y patrones antes de crear otros. |
| ENG-002 | Corregir causas raíz en vez de acumular parches. |
| ENG-003 | Una fuente de verdad para reglas de negocio y persistencia; evitar duplicar lógica en UI. |
| ENG-004 | No añadir SQL, tablas, vistas, endpoints, capas ni dependencias sin necesidad funcional demostrable, modelo revisado y alternativa documentada. |
| ENG-005 | Documentar cambios relevantes: motivo, diseño, archivos afectados, riesgos, pruebas y limitaciones. |
| ENG-006 | Proteger datos, entornos productivos y permisos; no realizar migraciones ni cambios destructivos durante tareas puramente visuales. |
| ENG-007 | Pruebas proporcionales al impacto y regresión en flujos afectados. |

## Por definir con el propietario
- Convenciones de nombres y carpetas.
- Capas arquitectónicas y separación de responsabilidades.
- Branching, revisión de PR, CI/CD y cobertura de pruebas.
- Dependencias, seguridad, logs, contratos API y gestión de base de datos.
- Límite universal de líneas por archivo.

**No asumir que 300 líneas es regla global.** Actualmente pertenece sólo a SmooControl (SMO-001).
