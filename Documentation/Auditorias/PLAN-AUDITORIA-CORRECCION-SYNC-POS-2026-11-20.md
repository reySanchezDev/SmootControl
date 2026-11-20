# Auditoría y cierre de sincronización POS — 2026-11-20

## Objetivo y alcance

Corregir el fallo reportado al sincronizar el catálogo desde el POS sin duplicar
la cola, sus estados ni el mecanismo de reintentos existente. Validar ida y
vuelta de catálogo/ventas con la API canónica, publicar la rama de corrección y
entregar un APK Android Release instalable. No cambiar el POS local-first ni
los datos históricos, credenciales o claves de Supabase.

## Hallazgos confirmados

1. La captura reporta HTTP 404 / `42883`: el cliente invoca
   `pos_pull_operational_catalog`, cuya implementación anterior dependía de
   `pos_pull_operational_catalog_legacy_20261117`; la migración 115 había
   eliminado esa función heredada. La RPC pública requerida no estaba
   disponible en el esquema desplegado.
2. La cola offline, estados de éxito/error, consulta de pendientes, botón manual,
   sincronización al inicio y temporizador ya existen. No se crea una cola ni
   otro estado de reintento.
3. La sincronización automática está condicionada a `autoSyncEnabled` y se
   ejecuta con el mismo `SyncSchedulerService.runNow()`/`SyncQueueProcessor`.
   Se añaden disparadores al reanudar la app y recuperar conectividad; no
   sustituyen el temporizador ni la acción manual.
4. El botón manual primero procesa la cola y luego descarga el catálogo. El
   resultado debe distinguir fallos parciales de cola de fallos de descarga y
   no afirmar éxito antes de completar ambas etapas.

## Plan medible y avance

| Fase | Criterio verificable | Estado |
|---|---|---|
| A. Auditar flujo/duplicación | Trazar `main` → scheduler → procesador FIFO → RPCs y UI; identificar estados/reintentos ya existentes. | ✅ Hecho |
| B. Corregir RPC de catálogo | Migración 135 define la firma esperada, valida dispositivo/tenant, lee `items` canónicos y conserva solo proyecciones JSON necesarias para clientes compatibles. | ✅ Implementado; pgTAP 8/8 pasó en la validación local previa y la migración remota 135 quedó aplicada/verificada en la ejecución previa. No se volvió a tocar producción. |
| C. Reintento automático | Reusar cola FIFO; respetar `autoSyncEnabled`; disparar solo en inicio, intervalo, reconexión o reanudación, con exclusión concurrente existente. | ✅ Implementado y probado, incluida la exclusión de disparos solapados. |
| D. Feedback de sync manual | Reportar resultados reales de cola y descarga; errores de RPC no se presentan como sincronización exitosa. | ✅ Implementado; verificar pruebas de regresión |
| E. Validación local | `dart format`, análisis, pruebas de sync/POS y prueba SQL local de RPC/tenant/idempotencia según fixtures disponibles. | ✅ `dart format` sin cambios pendientes; `flutter analyze` sin errores; 83 pruebas de sync y 167 de POS/ventas/caja/inventario/empaques/catálogo en verde. `supabase status` y `docker info` se colgaron en esta continuación, por lo que no se repitió pgTAP (8/8 constaba de la ejecución local previa). |
| F. Publicación y artefacto | Revisar diff; commit y push de la rama de corrección; compilar con el script oficial, comprobar defines, versión, permisos y SQLite nativo. | 🟡 APK generado y verificado; commit/push pendientes |

## Resultado del APK

- Ruta: `release/SmooControl-produccion-0.1.93-98.apk` (80,212,085 bytes).
- SHA-256: `28914EFBEE3BF0108FFB7DC4AC87EB9D3281CC0918EE2696CB9828C200D94D84`.
- `apksigner verify`: válido, firma v2; paquete `com.smoocontrol.pos`, versión
  `0.1.93`, versionCode `98`.
- El script oficial registró los tres defines requeridos por nombre; Internet y
  `libsqlite3.so` están presentes. El archivo privado se leyó por ruta y no se
  copió al repositorio.

## Pruebas de aceptación

- Catálogo: la app llama `pos_pull_operational_catalog` con el contrato de
  dispositivo; respuesta 200 actualiza maestros locales y no consulta
  `products`/la RPC legacy.
- Tenant/dispositivo: credenciales inválidas o dispositivo de otro restaurante
  son rechazados por la función; no se devuelven datos de otro tenant.
- Cola: el mismo `SyncQueueProcessor` procesa FIFO; éxito marca sincronizado,
  error persiste el mensaje y queda reintentable, y los casos que requieren
  resolución no se reenvían automáticamente.
- Reintentos: `autoSyncEnabled=false` no dispara; al estar activo, startup,
  temporizador, reconexión y resume invocan el mismo proceso sin concurrencia
  duplicada.
- Flujo manual: ventas en cola se envían antes de descargar catálogo; la UI
  muestra conteos reales y distingue fallo parcial de fallo de descarga.
- Release: APK de flavor `production`, `0.1.93+98`, define solo URL, publishable
  key y restaurante privados, permisos de Internet presentes y
  `libsqlite3.so` embebido. Nunca usar `service_role`.

## Riesgos y límites

- El equipo físico no está conectado durante esta sesión: el flujo Android real
  deberá confirmarse instalando este APK y observando cola/ventas en producción.
- Migración 135 ya fue aplicada según la ejecución previa; no volver a aplicar
  ni modificar producción durante el build. Confirmar su estado de solo lectura.
- El APK no se considera entregado hasta que el script finalice y las
  verificaciones del artefacto pasen; una respuesta HTTP o un APK anterior no
  cuentan como éxito.
