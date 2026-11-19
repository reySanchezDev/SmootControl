# Acta de remediación — auditoría Items end-to-end

**Fecha:** 2026-11-19
**Base de implementación:** `main` `4181999ee58ba9eb65ec96d13b48de95ee2669cb`
**Rama:** `fix/audit-items-end-to-end-2026-11-19`
**Alcance:** correcciones locales en rama aislada y pruebas contra Docker local. Sin cambios en `main`, producción ni Supabase remoto.

## Decisiones y resultados

| Hallazgo | Resultado en esta remediación |
|---|---|
| A01 — Productos con ruta legacy | Consolidada la ruta administrativa a maestro canónico; removido el widget de vista legacy y evitada la lectura legacy de Productos. |
| A02 — envío alternativo de ventas | Ruta sin credenciales de dispositivo falla de forma cerrada; ventas POS requieren RPC versionado/atómico. Prueba dirigida añadida. Cola local no se elimina. |
| A03 — snapshot y proyección separados | Snapshot, proyección local y metadatos quedan en la misma transacción; ACK remoto posterior al commit. Prueba de rollback conjunto añadida. |
| A04 — stock residual en proyección | El artículo no inventariable proyecta existencia local cero; no se borra estado legacy de otros tenants. Prueba dirigida añadida. |
| A05 — `source_kind` y puente legacy | No se retiró: falta demostrar cero clientes/consumidores y cerrar compatibilidad de dispositivos. Riesgo abierto, no resuelto por cambiar una condición aislada. |
| A06 — `DROP ... CASCADE` histórico | Migración 117 no se reescribió. No se promueve ni reaplica aquí; una migración aplicada requiere diagnóstico aditivo/preflight en su ambiente destino. |
| A07 — versión de catálogo/colas | Se conservaron los guards existentes y la cola; no se habilitó reclasificación. Falta E2E concurrente con dos dispositivos para certificar el gate distribuido. |
| A08 — revisión de clasificaciones | No se amplió el contrato de revisión: los enlaces son descriptivos y no se demostró que alteren la operación POS. Mantener prueba contractual y revisar si cambia su semántica. |
| A09 — movimiento sin tracking | Migración 134 valida `tracks_inventory`, previene escritura de movimiento/saldo para artículo no rastreable y detecta reutilización conflictiva de ID. SQL transaccional pasó en Docker local. |
| A10 — privilegios helper legacy | Migración 132 revoca EXECUTE de `authenticated`; prueba ACL local confirma `false` para authenticated y `true` para service_role. |
| U01 — diálogos de subflujos | Se conserva: recetas y reglas son workflows secundarios; no son la ficha principal de edición en modal. No hay base para eliminar confirmaciones transaccionales. |
| U02 — abandono de ficha | Añadida guarda asíncrona al cerrar pestaña del workspace, reutilizando confirmación de cambios sin guardar. Prueba de veto añadida. Browser refresh/logout quedan fuera de esta guarda. |
| H01/H02 — textos y sentinels | Parte de la UI canónica aún contiene literales/fallbacks históricos. No se hizo conversión masiva sin ARB, claves y pruebas completas de ES/EN; queda pendiente. |
| H03 — permisos | La vista/editor usa permisos efectivos recibidos; se retiró el bypass administrativo por rol fijo. Pruebas de editor cubren permisos. |
| E01 — tamaño de archivos | Los dos archivos de aplicación ampliados por la remediación quedan bajo 300 líneas tras separar responsabilidades. Otros archivos heredados señalados por la auditoría permanecen como deuda; no se aplicó una división mecánica. |
| E02 — reemplazos textuales históricos | Migraciones aplicadas 124/127/129–131 no se alteraron. Migración 134 nueva define su función directamente. Requiere prueba de upgrade en clon representativo antes de release. |
| E03 — cobertura CI/E2E | Se ejecutaron pruebas dirigidas locales, no se declara CI ni E2E en dispositivo certificado. Gate completo sigue pendiente. |
| D01/D03 — continuidad | Se añade esta acta y se actualiza el Plan Rector y contexto con evidencia, SHA base y pendientes. La historia previa se conserva. |
| D02 — estándar | No se alteraron identificadores normativos ni política universal; requiere sincronización ratificada del estándar central. |
| P01 — reclasificación | Se mantiene función operativa inmutable en edición. Sin cambio de política ni migración para habilitarla. |

## Migraciones locales

- 132: privilegios del filtro legacy de movimientos.
- 133: grupos de modificadores en snapshot canónico del POS.
- 134: movimiento de inventario condicionado por `tracks_inventory` e idempotencia/conflicto de ID.
- Las tres se aplicaron únicamente al Supabase Docker local. Se comprobó versión local 134 y se ejecutaron pruebas SQL con `ROLLBACK`. No se consultó ni modificó producción.

## Verificación de aplicación

- `dart format`: ejecutado sobre archivos Dart cambiados.
- `flutter analyze`: repetido tras refactor/formato; **sin errores**.
- Suite dirigida final: **24 pruebas aprobadas** en siete archivos, incluidos workspace, permisos/editor, snapshot/aplicador/rollback, proyector, sender y ruta de Productos.
- SQL local: ACL de función legacy y restricción de movimiento no rastreable aprobadas.
- RELEASE oficial completado con `tool/build_web_release.ps1 -CanonicalItemsQa -LocalSupabaseQa` y credencial privada de QA local fuera del repositorio. El script validó la URL Docker y clave publicable; Auth local respondió HTTP 200. El bundle contiene la URL local; el modo `backoffice` se fijó por el script oficial.
- Artefacto servido en `http://127.0.0.1:8105/`; comprobación HTTP devuelve 200. No se hizo inspección visual/responsive: el conector de navegador no está disponible en esta sesión. QA visual de propietario sigue pendiente.
- Fuentes y pruebas nuevas/modificadas comprobadas <=300 líneas; `git diff --check` sin errores. Existen otros archivos heredados mayores a 300 no tocados por esta remediación.
- Pendiente: QA visual del propietario, prueba E2E de venta POS/dispositivo y los riesgos históricos descritos en la matriz. No promover a producción con estos gates abiertos.

**Resultado:** remediación parcial verificada localmente; no certifica producción ni cierra los riesgos A05–A08, H01/H02, E02/E03 ni pruebas E2E de dispositivo.
