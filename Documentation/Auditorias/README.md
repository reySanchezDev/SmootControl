# Bitácora de auditorías — SmooControl / Kivo

Las auditorías se preservan con ID, fecha, rama/commit, alcance, evidencias por archivo, hallazgos, riesgos, límites, decisiones y próximos pasos. Reutilizar la evidencia anterior y revisar los cambios desde el último corte; no repetir auditorías completas salvo evidencia de inconsistencia.

**Reglas:** auditar no autoriza implementar. Diferenciar código versionado de producción comprobada. No ejecutar SQL ni tocar datos por una auditoría documental. Cualquier implementación posterior necesita aprobación, plan de rollback y QA.

| ID | Tema | Estado |
|---|---|---|
| [AUD-2026-11-06-001](AUD-2026-11-06-001-maestro-articulos.md) | Productos, empaques, modificadores, recetas y POS | Revisión estática inicial terminada; riesgos abiertos |
| [AUD-2026-11-06-002](AUD-2026-11-06-002-dependencias-y-migracion-articulos.md) | Drift, Supabase, ventas, sync, pruebas y transición reversible | Mapa principal documentado; esquema y datos reales pendientes |

**Próxima comprobación pendiente:** catálogo de dependencias completo y contraste con esquema/datos reales y clientes POS activos, sin implementación hasta autorización explícita.
