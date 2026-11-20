# Auditoría y cierre de sincronización POS — 2026-11-20

## Objetivo y alcance

## Hallazgo adicional: timestamps POS interpretados con zona incorrecta

- Evidencia remota: la factura `F-1332` tenía `sold_at` y la línea a las
  `15:11:09.098453Z`, mientras caja y recepción de la venta ocurrieron a las
  `21:10:54Z` y `21:11:09.458203Z`. Al sumar seis horas, el instante de venta
  queda `21:11:09.098453Z`, 0.36 segundos antes de la recepción.
- Causa: la cola serializaba `DateTime` local sin sufijo de zona; Postgres
  asumía UTC al convertir a `timestamptz`.
- Corrección: serializar ventas y líneas nuevas con sufijo UTC; normalizar en
  el emisor los registros antiguos pendientes interpretando su timestamp sin
  zona en el huso del dispositivo. La fecha comercial sigue siendo local.
- Datos: corregidos únicamente `sold_at` de `F-1332` y `created_at` de su línea
  por +6 horas, protegidos por IDs, restaurante, caja, POS, estado, número de
  factura y valores anteriores exactos. No se cambió esquema/RPC ni se creó
  migración.
- Validación de código: `dart format` y `flutter analyze` sin errores; las dos
  pruebas focalizadas de serialización nueva y normalización de cola anterior
  pasaron. Una corrida más amplia con dos suites heredadas excedió el límite
  de 300 s de la herramienta de pruebas y no se toma como resultado de fallo.
- Validación de cliente: generar APK posterior a `0.1.94+99`; QA del instante
  de una nueva venta queda pendiente en el teléfono del propietario.

## Seguimiento adicional: inicializacion y cola automatica (2026-11-20)

La revision del incidente posterior detecto dos omisiones: el scheduler tenia
implementados inicio/temporizador pero nunca se invocaba `start()`; y el restore
insertaba `device.initialize` directamente en la cola sin despertarla. Como el
envio inmediato respeta FIFO, esa auditoria podia quedar delante de todas las
ventas hasta la accion manual.

| Criterio | Avance |
|---|---|
| Iniciar scheduler solo en la app POS, con startup y periodo configurados | Implementado; validar en analisis y pruebas |
| Despertar la cola al completar restore, respetando `syncOnSave` y sin invalidar el restore local ante fallo remoto | Implementado; validar en pruebas |
| Mantener reconexion/reanudacion y no activar sync POS en Backoffice/Marcador | Implementado; validar |
| Pruebas de scheduler e inicializacion | Añadidas; ejecutar |
| APK nuevo, posterior a `0.1.93+98`, verificado y copiado a `SmooControl/release` | Pendiente de build |
| Confirmacion funcional con dispositivo real | Pendiente: la cola Drift del telefono no esta disponible para inspeccion remota |

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
| F. Publicación y artefacto | Revisar diff; commit y push de la rama de corrección; compilar con el script oficial, comprobar defines, versión, permisos y SQLite nativo. | ✅ Publicado en `fix/pos-sync-e2e-2026-11-20`; SHA confirmado local/remoto `96440694324d6563a0bf97a006009a0cf864b075`. APK generado y verificado. |

## Seguimiento 2026-11-20: cola tras inicialización

- Hallazgo reproducido por trazado: `device.initialize` se agrega primero a la
  cola FIFO; el envío inmediato de ventas se omite correctamente mientras haya
  un elemento más antiguo. Además, el scheduler no se iniciaba en el ciclo de
  vida normal de la app. Por eso el botón manual vaciaba el bloqueo inicial y
  luego parecía "despertar" la sincronización.
- Corrección: iniciar el scheduler solo en modo POS, despertarlo después de
  confirmar localmente la inicialización y ejecutar el ciclo inicial antes de
  dejar el temporizador periódico activo. `syncOnSave` conserva su semántica
  aunque el reintento periódico esté desactivado; FIFO y exclusión mutua se
  mantienen.
- Validación comprobada: `dart format` aplicado; `flutter analyze` sin errores;
  37 pruebas dirigidas de inicialización, scheduler, cola, sincronización y
  ventas pasaron. No hay emulador/dispositivo disponible para observar una
  cola Drift física; esa comprobación queda para la nueva instalación.
- APK oficial `production`: `release/SmooControl-produccion-0.1.94-99.apk`,
  80,212,081 bytes, SHA-256
  `D0ACD6D4CB6167CC435A6007991F76FF9937D34DF281D7417D6D64291663F3E1`;
  firma v2 válida; paquete `com.smoocontrol.pos`, versión `0.1.94`,
  versionCode `99`. Se generó mediante el script oficial con credenciales
  privadas; no se incluyeron secretos en Git.
- Pendiente de QA propietario: reinstalar/inicializar el APK, abrir caja y
  observar si la primera venta se sincroniza sin tocar "Sincronizar datos".
  No se inspeccionó ni se afirma acceso a la cola local del teléfono.

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
