# G2 — QA físico y corte reversible (solo entorno autorizado)

**Estado:** procedimiento de aceptación, no aprobación de G2 ni instrucción de despliegue.
**Regla:** no usar producción, no ejecutar migración `088`, no activar flujos POS hasta que el propietario apruebe expresamente un laboratorio con copia no sensible de datos y respaldo probado.

## Evidencia previa comprobable
- PR #37: GitHub Actions `43063614835`, 14 jobs correctos, 1 Flutter omitido por diff no-Dart; PostgreSQL 16 sintético.
- PR #36: GitHub Actions `43060509843`, 14 jobs correctos, 416 tests Flutter y 17 problemas heredados del analizador, sin incremento.
- El test de **dos SQLite independientes** de este PR es simulación: no demuestra dos dispositivos físicos ni conflictos en Supabase.

## Gate de seguridad — sin cambiar la base
1. Propietario identifica explícitamente **proyecto Supabase de laboratorio**, sucursal/tenant, roles de ensayo y dispositivos autorizados. Si faltan, NO ejecutar consultas reales.
2. Ejecutar solo `supabase/tests/item_core_g2_real_schema_readonly_audit.sql` con cuenta de consulta autorizada. Es inventario de objetos, políticas RLS y permisos; **no** simula JWT firmado ni afirma acceso denegado solo por existir una policy.
3. Comparar la firma y los permisos reales de `app_upsert_item_v2`, `app_upsert_item_unit_v2`, clasificaciones, reglas y `pos_pull_item_catalog_v2`. Validar JWT firmado de al menos dos usuarios de tenants diferentes, usuario sin permiso y sesión caducada **contra el esquema real**. Usar registros de prueba sin PII.
4. No habilitar escrituras si faltan políticas, permisos, controles del tenant, historial de migraciones, plan de reversión o prueba de respaldo/restauración.

## Gate funcional — dos terminales físicas
Con dos terminales A/B del mismo restaurante en **laboratorio** y una tercera identidad de otro restaurante:
- Capturar `snapshot_id`/revisión inicial y saldo por SKU. Preparar ventas de prueba y conexión intermitente.
- Terminal A y B descargan el mismo catálogo; comprobar que un artículo oculto/inactivo no aparece para venderse pero mantiene su identidad en el almacén canónico.
- Desconectar B; en A registrar venta, ingredientes/empaque, ajuste y anulación. B registra una venta offline diferente. Cada venta debe tener identificador idempotente único.
- Publicar revisión del catálogo y sincronizar A. Reconectar B; verificar que **no desaparezca su cola** y que reciba la revisión íntegra exactamente una vez.
- Reenviar cada evento de venta/anulación dos veces con el mismo identificador. Confirmar **una** venta, **una** anulación, sin doble movimiento de inventario, con ledger consistente.
- Forzar un fallo de red tras envío confirmado y repetir; verificar recuperación del mismo resultado sin duplicados. Rechazar un snapshot anterior, incompleto o de otro tenant.
- Verificar inventario final, colas vacías o errores explícitos, auditoría de permisos y tiempos. Confrontar datos de las dos terminales con servidor.
- Probar rollback controlado de ruta de catálogo **antes** de habilitar cualquier tráfico real: desactivar feature flag en laboratorio y confirmar que POS legacy y ventas pendientes siguen operando. El rollback de código **no** implica revertir ventas confirmadas.

## Criterio de aprobación
G2 permanece **ABIERTO** hasta evidencia firmada de: JWT/RLS real, registros del test físico A/B, idempotencia de venta/anulación en backend, conservación de ventas offline, respaldo/restauración y decisión explícita del propietario. Cada evidencia debe referir entorno, commit, revisión, timestamp, resultado y responsable.

**No autorizar producción por el solo hecho de pasar GitHub Actions.**
