# FE-E2 — Reparación incremental del contrato de anulación remota

**Fecha:** 2026-11-06  
**Estado:** pendiente de ejecución de Codex en Docker; **no aprobado para producción**.  
**Rama:** `fix/packaging-sale-void-contract`, derivada de `audit/kivo-packaging-e2e`.  
**Evidencia precedente:** FE-E1: Flutter analyze sin incidencias, 22/22 Ventas, 7/7 Inventario, 47/47 Sincronización, 7/8 escenarios locales; anulación remota bloqueada por `sale_voids.original_total_amount NOT NULL`.

## Causa verificada en SQL versionado

- `001_initial_schema.sql` crea `sale_voids.original_total_amount numeric(15,4) NOT NULL`, junto con los campos de método/pago originales.
- `010_pos_device_sync.sql` inserta `sale_voids` incluyendo total, método y referencia originales.
- `019_pos_sync_sale_remote_invoice_authority.sql` redefine la función e inserta sólo `sale_id, restaurant_id, voided_by_user_id, reason, voided_at`, omitiendo el campo obligatorio.
- Migraciones posteriores envuelven/renombran `pos_sync_sale`. Reescribir la función original de 450 líneas en una migración sería un cambio más amplio y riesgoso.

## Solución propuesta en código

`supabase/migrations/084_restore_sale_void_historical_snapshot.sql` agrega un trigger **BEFORE INSERT** que resuelve por `(sale_id, restaurant_id)` la venta y completa `original_total_amount`, `original_payment_method_id`, `original_payment_reference`, `cash_register_session_id`. Rechaza referencias de otro restaurante y no elimina historial ni cambia columnas. No modifica ni reemplaza los wrappers existentes.

**Alcance deliberado:** se corrige la omisión del snapshot al insertar, no la semántica de UPDATE del RPC ni el problema potencial de una venta retransmitida con totales diferentes. Es obligatorio verificar por separado que el flujo no cambia importes históricos al anular, no actualiza snapshots existentes y no crea movimientos duplicados. El trigger no intenta reparar otros defectos de contabilización o permisos.

## Validación obligatoria de Codex antes de aprobar

1. Confirmar aislamiento real `127.0.0.1:54321/54324`, destinatario local y existencia de 83 migraciones. No reiniciar la pila si se perderían bindings seguros.
2. Verificar esquema real (`\d public.sale_voids` o `information_schema`), triggers y función efectiva `public.pos_sync_sale`; contrastar con archivos SQL. Registrar diferencias.
3. Aplicar **únicamente la migración local 084** (sin `db reset` ni comandos linked/remote) con el mecanismo admitido por la CLI o mediante conexión PostgreSQL local controlada.
4. Comprobar 84 registros de migración si se usó el sistema de migraciones, y que el nuevo trigger existe. Si se aplicó SQL manual sin registrar versión, documentar la diferencia y no declarar `84/84`.
5. Repetir anulación remota RPC con `void` sintético: venta ya sincronizada, primera anulación, reenvío de anulación, stock de empaque, inventario/receta, caja, payload de respuesta y `sale_voids` (total, método, referencia, sesión). Confirmar atomicidad, idempotencia y compatibilidad.
6. Probar inconsistencia de `restaurant_id`/venta inexistente, ausencia de autorización y concurrencia básica de dos terminales. Las operaciones deben ser exclusivamente de laboratorio y con datos sintéticos.
7. Ejecutar `flutter analyze`, suites Ventas/Inventario/Sync y verificar que la corrección no exige modificar Flutter. Registrar conteos y exit codes.
8. Si el trigger evidencia problemas no cubiertos (por ejemplo, totales cambiantes, estado `sync_status`, reintento tras void, saldo remoto inverso), **no ocultarlos**: documentar causa, preparar corrección mínima separada y volver a probar.
9. Mantener `QuantixEngineeringStandar` ENG-008/UX-041, y preservación de datos históricos e IDs. No usar datos de producción ni publicar secretos.
10. No aplicar 084 a producción; no fusionar PR #9 sin revisión de resultados.

## Resultado de ejecucion local — 2026-11-07

Worktree: `SmooControl-packaging-void-lab`. Destino exclusivo: Supabase Docker local por loopback.

- `supabase migration up --local --workdir . --yes`: completado sin reset.
- Migraciones registradas: **84/84**.
- Trigger `sale_voids_snapshot_originals_before_insert`: presente.
- Puertos verificados: `127.0.0.1:54321` y `127.0.0.1:54324`.
- Venta sintetica y anulacion mediante `pos_sync_sale`: aprobadas.
- `sale_voids` conservó importe, metodo, referencia y sesion de caja originales.
- Stock de empaque reintegrado de 7 a 8 con un movimiento `packaging_sale_void`.
- Reenvio idempotente: una fila de `sale_voids`, un movimiento de reversa y sin cambio adicional de saldo.
- Referencia cruzada de restaurante rechazada por el trigger.
- Reenvio exacto sin alteracion del snapshot historico.
- Permisos y politica existentes de `sale_voids` sin cambios.

Validacion Flutter:

- `flutter analyze --no-pub`: **OK, No issues found**.
- Ventas: **22/22**.
- Inventario: **7/7**.
- Sincronizacion: **47/47**.

No fue necesario modificar Flutter, repositorios, permisos ni migraciones adicionales. El gate queda aprobado para laboratorio local exclusivamente; no se aplico 084 a produccion.

## Gate

**G-E2 aprobado para laboratorio local.** La migración 084 y el flujo RPC quedan
validados únicamente con fixtures sintéticos en Docker local. No se aplicó ni se
debe aplicar esta migración a producción desde esta ejecución.
