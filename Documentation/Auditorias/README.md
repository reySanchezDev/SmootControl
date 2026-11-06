# Bitácora de auditorías — SmooControl / Kivo

Las auditorías se preservan con ID, fecha, rama/commit, alcance, evidencias por archivo, hallazgos, riesgos, límites, decisiones y próximos pasos. Reutilizar la evidencia anterior y revisar los cambios desde el último corte; no repetir auditorías completas salvo evidencia de inconsistencia.

**Reglas:** auditar no autoriza implementar. Diferenciar código versionado de producción comprobada. No ejecutar SQL ni tocar datos por una auditoría documental. Cualquier implementación posterior necesita aprobación, plan de rollback y QA.

| ID | Tema | Estado |
|---|---|---|
| [AUD-2026-11-06-001](AUD-2026-11-06-001-maestro-articulos.md) | Productos, empaques, modificadores, recetas y POS | Revisión estática inicial terminada; riesgos abiertos |
| [AUD-2026-11-06-002](AUD-2026-11-06-002-dependencias-y-migracion-articulos.md) | Drift, Supabase, ventas, sync, pruebas y transición reversible | Mapa principal documentado; esquema y datos reales pendientes |

| [AUD-2026-11-06-003](AUD-2026-11-06-003-referencia-ls-central-drive.md) | Referencia LS Central documentada en Google Drive y preguntas SQL para Codex | Revisión documental; comportamiento real pendiente |

| [AUD-2026-11-06-004](AUD-2026-11-06-004-backend-terminales-pos.md) | Dispositivos POS existentes, caja, sync y brechas de terminal configurable | Auditoría estática terminada; esquema real y QA pendientes |

| [AUD-2026-11-06-005](AUD-2026-11-06-005-numeraciones-consecutivos-documentos.md) | Facturas, folios, offline, doble emisión y documentos omnicanal | Riesgo bloqueante G-NUM; simulación y verificación fiscal pendientes |

| [AUD-2026-11-06-006](AUD-2026-11-06-006-ls-central-statement-y-numeracion.md) | LS Central: transacción, recibo, statement, contabilización y folio fiscal | Documentación oficial contrastada; SQL de caso real pendiente |

**Próxima comprobación pendiente:** catálogo de dependencias completo y contraste con esquema/datos reales y clientes POS activos, sin implementación hasta autorización explícita.
