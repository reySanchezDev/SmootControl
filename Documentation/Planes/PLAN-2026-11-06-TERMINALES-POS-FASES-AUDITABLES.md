# KIVO — Plan maestro de terminales POS por fases auditables y simulables

**Versión:** 1.0 · **Fecha:** 2026-11-06 · **Estado:** PLAN PROPUESTO, sin implementación ni autorización de ejecución.  
**Auditoría base:** [AUD-004](../Auditorias/AUD-2026-11-06-004-backend-terminales-pos.md) sobre `develop/backoffice-stabilization-integration` (SHA `7ce5163e0c6e698397dca0f57689966a4b714649`); [arquitectura omnicanal](../Diseno/KIVO_ARQUITECTURA_FUNCIONAL_OMNICANAL_V1.md), [AUD-002](../Auditorias/AUD-2026-11-06-002-dependencias-y-migracion-articulos.md). Actualizar SHA y delta antes de iniciar. El comportamiento de la base Supabase viva no está verificado.

## Resultado final esperado

**Evolucionar `public.pos_devices` y la identidad local existente** para operar terminales administrables: nombre/código, estado, asignación de sucursal, múltiples tipos de venta permitidos, uno predeterminado, herencia de reglas y auditoría. Sin destruir credenciales, UUID, cajas, movimientos, ventas o sincronización. Posponer aplicaciones web/QR/delivery sin bloquearlas: canal de origen **distinto** de modalidad de servicio, y órdenes externas no sometidas artificialmente a permisos de una terminal física.

El alcance de este plan es la **capacidad de terminales y modalidades**; disponibilidad estacional, catálogo maestro y motor completo de órdenes omnicanal se enlazan como contratos dependientes, pero tienen sus propios proyectos y pruebas. No introducir funcionalidades no acordadas en silencio.

## Reglas innegociables y control de cambios

1. **El plan no autoriza ejecutar nada.** No SQL en entornos reales, despliegue, borrado del piloto, cambios Drift ni alteraciones a branch de producción sin aprobación expresa por fase.
2. Fases **secuenciales y con compuerta (gate)**; entregar artefactos, evaluación y decisión: `APROBADO` / `APROBADO CON CONDICIONES` / `RETRABAJO` / `DETENIDO`. **No pasar a la fase siguiente hasta confirmación del usuario.**
3. Antes de cada cambio: evaluar con simulación apropiada. **`SELECT` / `EXPLAIN` / análisis estático** para observación, pruebas de migración **solo en clon aislado**. No llamar «dry run» a ejecutar DDL contra producción con `ROLLBACK`: funciones, efectos externos y concurrencia pueden hacerlo inseguro.
4. Resultados de simulación deben ser reproducibles (versión de código, esquema, datos sintéticos o anonimizados, comandos ejecutados, expectativas, resultados y fallos). Nunca afirmar que un test pasó sin ejecutarlo.
5. Backups y rollback documentados y **probados en clon** antes de cambios en producción. Migraciones aditivas compatibles; preferir inhabilitar por feature flag en rollback a reconstruir registros mediante SQL destructivo.
6. Logs sin claves de dispositivo, tokens, datos sensibles ni registros de clientes. Restaurar un entorno aislado con datos sintéticos; aislar emails/SMS/pagos, impresión, KDS y servicios externos para que ninguna simulación cause operaciones reales.
7. **Criterio multi-tenant:** FK/validación por restaurante y sucursal, RLS, autorización en RPC `SECURITY DEFINER`, sin confiar en `restaurant_id` o permisos enviados por cliente.
8. **No diseñar por analogía ciega a LS Central**: conservar su útil patrón multi-sales-type pero separar origen `APP`/web de modalidad `delivery`/recoger/comer aquí.

## Etapas y dependencias

| ID | Fase | Entregable observable | Tipo de simulación | Gate |
|---|---|---|---|---|
| F0 | Línea base e inventario | Mapa real de versiones, dependencias, objetos y dispositivos | Solo lectura y comparador de esquema | G0 |
| F1 | Modelo funcional y experiencia | Prototipo interactivo de configuración y matriz de reglas | Simulador UX con escenarios de negocio | G1 |
| F2 | Contratos, amenazas y datos | Esquema lógico, API, estados, permisos, compatibilidad | Tests de invariantes y matrices de decisión | G2 |
| F3 | Migraciones y compatibilidad | SQL aditivo candidato + Drift candidato, sin ejecutar en real | Migración repetible en clon aislado y rollback | G3 |
| F4 | Backend y seguridad | RPC CRUD/lecturas, herencia, scope y auditoría | Integración multi-tenant, concurrencia, fallos | G4 |
| F5 | Distribución a terminales/offline | Pull versionado, caché local y activación gradual | Emulator de terminales, desconexión y reintentos | G5 |
| F6 | POS + Backoffice | Configuración clara y selector validado por terminal | Simulación táctil + regresión de caja/ventas | G6 |
| F7 | QA integral y ensayo de lanzamiento | Evidencias E2E, métricas, ensayos de reinstalación | Ensayo cerrado sobre entorno staging con dispositivos | G7 |
| F8 | Liberación controlada | Runbook, banderas, observabilidad, corte y rollback | Canario, monitoreo y ensayo de reversión | G8 |

## F0 — Evidencia actual y detección de huecos (solo lectura)

**Auditar** todas las migraciones relevantes **hasta la última realmente aplicada** y comparar con esquema activo: `pos_devices`, `sales_types`, `sales`, `cash_register_sessions`, `sync_logs`, tabla de dispositivos local, roles, RLS, índices, triggers, funciones finales (incluidos wrappers `pos_sync_sale`, `pos_pull_operational_catalog`, `register_pos_device`, `assert_pos_device`). Confirmar rama activa, apps y versiones Android desplegadas, restauración y colas pendientes. Verificar si otra rama ya implementó configuraciones o sucursales para no duplicarlas. Identificar dependencias por funciones, tablas, FKs, tests y UX.

**Simular:** inventario de configuraciones sin datos privados (dispositivos activos/inactivos, counts de sales types, terminales por restaurante, ventas y cajas por dispositivo, colas por versión), comparación esquema declarado-vivo y grafo de dependencias. Queries `SELECT` sobre metadatos y agregados aprobados; si no hay acceso real, registrar `NO VERIFICADO`, no completar el gate.

**Gate G0:** mapa real de consumidores y riesgos, cobertura de dispositivos actuales, identificadores estables, cobertura de tests de regresión y divergencias de despliegue. Responsable técnico revisa; usuario decide autorizar F1. **Sin cambios a código ni datos**.

## F1 — Simulador funcional de la experiencia (sin backend)

Preparar prototipo UX **realmente interactivo** y desacoplado de backend: negocio → sucursal → terminal; modal «Modalidades permitidas» (checklist) + «Predeterminada» (radio del subconjunto); herencia `inherit` y configuración `custom`, orden, estado, mensajes de error claros. No ocultar acciones bajo «… Más». Permitir varios sales types, como muestra LS.

**Casos explorables:** restaurante con una sucursal y tres terminales; una caja solo pickup; una caja con comer aquí/llevar/delivery; nueva terminal heredada; desactivar un tipo por sucursal; cambiar predeterminado; suspensión; crear pedido de origen web cuya cobranza ocurre en POS. Mostrar **qué verá el cajero**, **qué permite backend** y cuál sería el resultado al cambiar modalidad. Incorporar variante cafetería, restaurante mesa y dark kitchen.

**Gate G1:** aprobación visual y funcional de flujos; tabla de escenarios y reglas sin contradicciones. Aceptación del usuario explícita; no se autoriza F2 automáticamente.

## F2 — Contratos y reglas que no pueden fallar

Definir:
- Identidad existente `pos_devices.id` vs código visible; alta, rotación credencial, suspensión y retiro.
- Modalidades `sales_types` por restaurante; políticas por sucursal y tabla N:M `pos_device_sales_types` (nombres finales por definir), `default_sales_type_id`, `inherit/custom`. Fallback legacy para POS antiguo.
- En ausencia inicial de sucursales físicas, **sucursal principal virtual** por restaurante; no forzar migración de todos los módulos a multi-sucursal en esta fase.
- Validación `default ∈ permitted ∩ active ∩ location_allowed` y ausencia de conjuntos vacíos salvo terminal deshabilitada. Transiciones atómicas al suspender tipo o reubicar dispositivo.
- Inmutabilidad de `origin_channel`, distinta de `sales_type_id`/modo; terminal física no es necesariamente origen inicial de pedido web.
- Prioridad definida: autorización tenant → dispositivo activo → sucursal → modo activo → permisos de terminal → override temporal → decisión de orden. Un default local no puede superar bloqueo backend.
- Versiones de configuración, notificación de cambios, caducidad offline y captura de snapshot/version al iniciar orden. Orden ya creada bajo política anterior debe tener reglas de aceptación/revisión previsibles.
- Modelo de amenazas: `SECURITY DEFINER`, ID ajeno, secreto robado, reasignación cross-tenant, `ON CONFLICT` del registro, API pública y abuso.
- Contrato backward-compatible para `pos_pull_operational_catalog` y entidades locales; qué ocurre con clientes anteriores sin configuración.
- UI del backoffice, permisos mínimos, auditoría de quién permite/retira modalidades.

**Simular:** tabla de verdad de estados y permisos, generador de órdenes sintéticas, cambios de modalidad mientras hay un ticket abierto, falla/reintento, reconfiguración masiva. Diseñar tests que fallen ante un hueco detectado.

**Gate G2:** diccionario de datos, diagrama de dependencias, matriz de autorización, contrato API, plan compatibilidad y criterios de rechazo listos; reabrir F1 si la UX no puede expresar reglas complejas.

## F3 — SQL/Drift candidato y migración ensayada EN CLON

Preparar migración *aditiva* versionada con constraints compuestas `(restaurant_id, id)` donde corresponda, referencias de tenant y relaciones N:M, defaults, checks, RLS y permisos. Sin duplicar UUID de `pos_devices`. Plan de crear sucursal principal virtual sin romper `restaurants`. Migración local de caché en Drift no destructiva, comprobación desde `schemaVersion` anterior y APK previa.

**Ensayos en staging aislado:** dataset sintético con 1/2/10 terminales, sales types duplicados, distintos predeterminados, dispositivos inactivos, transacciones de venta y caja, claves inválidas, cliente legacy. Ejecutar migración, verificar integridad (conteos/FKs/constraints/índices), ejecutar otra vez si se promete idempotencia, verificar rollback lógico por banderas, reejecutar desde snapshot y comparar checksums de **catálogos e IDs**. Probar upgrade Drift sobre copia de una DB previa con cola.

**Gate G3:** scripts y pruebas reproducibles aprobados, no hay pérdidas/reescrituras inesperadas de identidad o catálogo; rollback ensayado. **Nunca** ejecutar en Supabase vivo por aprobar solamente G3: se necesita decisión explícita de despliegue.

## F4 — Backend seguro y administración remota

En rama de trabajo aislada: implementar repositorio/RPC de alta/edición/suspensión/consulta de configuración, separación de autorización y nombre mostrado; lectura de configuración efectiva, auditoría y revisionado transaccional. Asegurar que código cliente no puede enviar `sales_type_id` inválido aun si no se mostró chip. Validación de modalidad en frontera de orden/venta con política para tickets offline previos, sin rechazar eventos idempotentes ya aceptados.

**Simular:** 2 tenants, sucursales distintas, terminal ajena, sesión revocada, registro con ID existente, reactivación indebida, predeterminado inválido, actualización concurrente de modalidades y reintentos de RPC. Fuzz o pruebas de propiedad para invariantes de permisos.

**Gate G4:** 100 % pruebas de autorización críticas aprobadas y rutas legacy aún compatibles, sin regresión de caja/venta/sync. Revisar explícitamente función `register_pos_device`.

## F5 — Configuración descargada y offline

Extender pull del dispositivo para devolver `allowed_sales_types`, `default_sales_type_id`, `location_id`, `config_version`, `effective_at` y reglas de expiración. Guardar en Drift como caché, sin reemplazar identidad ni cola. Para dispositivos aún no migrados, comportamiento compatible de `sales_types.is_default` global, sin cambios abruptos. Definir handshake de versión, suspensión remota y qué hace el POS si está offline durante una revocación.

**Simulaciones:** 3 terminales distintas, configuración cambia con una desconectada; POS reinstalado; nuevo terminal; sync FIFO, venta creada offline con tipo posteriormente suspendido; reconexión duplicada; orden de caja y venta; conflicto de versiones; cambios de sucursal, pérdida de red en medio del pull. Probar que venta nunca se pierde ni se aplica dos veces.

**Gate G5:** matriz offline aprobada, reconciliación determinista y observabilidad de conflictos; no aceptar sincronización con datos de otro tenant.

## F6 — UX POS y Backoffice integrada

POS: chips únicamente de modalidades autorizadas, predeterminado por terminal, selector visible y táctil, señalización del origen de orden separada; antes de cambiar modalidad revalidar empaque/precios/reglas relevantes. Backoffice: navegación **Dispositivos POS** con listado, estado/actividad, terminal/sucursal y modal claro de modalidades permitidas, default y herencia. Modalidades de negocio fuera de «Empaques» sin romper funcionalidades actuales. Mantener diseño Executive Ivory.

**Simular:** flujos con restaurante, cafetería y dark kitchen; 1, 3 y 15 terminales; usuarios con permisos diferentes; resoluciones móviles/tablet/escritorio; orden QR transferida a caja; ticket abierto al cambiar tipo, cierre de caja, impresión y anulación. Capturas de antes/después y pruebas widget.

**Gate G6:** aceptación visual explícita del usuario, accesibilidad, regresión POS/caja y no duplicación de pantallas.

## F7 — QA funcional, técnico y fallos inducidos

Escenarios mínimos trazables:
1. Un terminal 3 modalidades y un default; segundo terminal 2 y otro default.
2. Restricción por sucursal y herencia; configuración custom; cambio de sucursal.
3. Suspender/reactivar terminal y tipo; modo predeterminado eliminado; cache vieja.
4. Caja simultánea en 2 POS; usuario mismo en dispositivos distintos; cierre/anulación.
5. Pedido origen web/QR con modalidad recoger/delivery y cobro en terminal.
6. Venta offline con empaque y receta, reintento, caída antes/después de confirmar remoto.
7. Stock insuficiente vs producto por temporada (ambas políticas separadas; aunque motor estacional tenga proyecto propio).
8. Autorización cross-tenant, inyección de IDs y denegaciones.
9. Upgrade de dispositivo desde APK vigente y reanudación de cola.
10. Reportes por dispositivo/modalidad/origen sin confundir semánticas.

Ejecutar `flutter analyze`, suites existentes y nuevas, builds oficiales según scripts del repositorio, SQL integration, widget/golden y E2E. Registrar totales **reales** de pruebas, fallos y correcciones, revisión de código y esquema. Probar restauración de backup **en staging**.

**Gate G7:** cero defectos críticos/altos sin resolver; tabla de aceptación firmada, observabilidad y runbook verificados. Cualquier anomalía reabre fase específica, no parchear a ciegas.

## F8 — Rollout por etapas y control comercial

- **Preparar:** congelar versión, respaldos, inventario de POS, colas y configuración, procedimiento de rollback.
- **Desplegar expand compatible** solo tras autorización explícita y comprobación del ambiente concreto. Migraciones y app desacopladas, APIs compatibles.
- **Canario** en una terminal/control de operador (si el usuario aprueba), habilitado con feature flag. Vigilar errores de validación, pedidos rechazados, diferencias de caja, sales types no autorizados, atrasos en sync.
- **Ampliar** a terminales restantes solo con evidencia de canario y nueva aprobación.
- **Rollback:** desactivar feature flag para volver al catálogo legacy y conservar datos/catálogos; nunca hacer `DROP` como rollback inmediato. Reconciliar órdenes creadas con nuevo contrato antes de retirar soporte.
- **Cierre:** medir errores operativos y soporte, establecer nuevas baselines, registrar mejoras futuras, fijar punto de corte del piloto en proyecto separado.

**Gate G8:** aceptación operativa y métricas observadas; cierre formal con documentación actualizada. No dar producción por verificada por el mero commit.

## Plantilla obligatoria para cada acta auditable

Crear `Documentation/Auditorias/FasesTerminales/FT-XX-<fecha>.md` sin sobrescribir auditorías anteriores:

```text
ID / fase / fecha / responsable:
Objetivo, requisitos y fuera de alcance:
Fuente exacta: rama, SHA, migraciones reales, entorno:
Hipótesis y escenarios:
Plan de simulación: datos sintéticos, comandos/queries, mocks y restricciones:
Resultados observados: esperado vs real, evidencia (logs/capturas) y casos fallidos:
Hallazgos: severidad (bloqueante/alto/medio/bajo), causa, acción, prueba de regresión:
Cambios propuestos vs ejecutados (distintos):
Compatibilidad: POS viejo/nuevo, offline, caja, ventas, API:
Verificación de seguridad y datos:
Backup, rollback, resultado del ensayo:
Criterios de salida y riesgos residuales:
Decisión Gate: PENDIENTE / APROBADO / CONDICIONAL / RETRABAJO / DETENIDO:
Autorización explícita del usuario (referencia, si existe):
Siguiente fase autorizada y límites:
```

Cada fase incluye **al menos un escenario adverso** diseñado deliberadamente para revelar huecos. Si el ensayo revela un caso no contemplado, registrar nueva hipótesis, extender matriz y repetir la prueba **antes** de aprobación.


## Dependencia bloqueante nueva — G-NUM: numeración documental (AUD-005)

**Referencia:** [AUD-2026-11-06-005](../Auditorias/AUD-2026-11-06-005-numeraciones-consecutivos-documentos.md). Debe cerrarse **antes de aprobar F2/F3**: el sistema hoy genera folio local y Supabase puede asignar otro al sincronizar; varias terminales offline, reimpresión y cierre de piloto afectan integridad de documentos. **No** diseñar serie fiscal por terminal sin validar requisitos regulatorios.

**Extensión F0:** inventariar cursor local, configuración `invoice_number_settings`, autoridad efectiva del RPC tras migraciones, rutas legacy, conciliación al volver del servidor, PDF, split payment, anulaciones, numeraciones de recibos internos y cleanup. Comprobar esquema real y consultas read-only.

**Extensión F1/F2:** simular decisión de 3 IDs (orden/venta/documento fiscal) y las estrategias online definitiva vs bloques reservados offline vs series físicas autorizadas. No confundir origen y tipo de servicio con serie legal.

**Ensayo independiente G-NUM (en simulador sintético aislado):** dos sucursales, cinco terminales, 50 ventas paralelas, tickets offline, respuesta RPC perdida, reintentos, cambio de serie y restauración; demostrar cero números definitivos duplicados, cero ventas perdidas, reimpresiones consistentes y folios no usados auditables. Registrar acta `Documentation/Auditorias/FasesTerminales/FT-NUM-<fecha>.md` con matriz de seguridad/compatibilidad y decisión explícita. Si el ensayo falla, bloquear F3 y rediseñar.

### Evidencia de LS Central para G-NUM

La [AUD-2026-11-06-006](../Auditorias/AUD-2026-11-06-006-ls-central-statement-y-numeracion.md) demuestra con documentación oficial que transacción POS, recibo, statement y documento fiscal son entidades distintas; la numeración fiscal **no se asigna universalmente al contabilizar el statement**. Comprobar reglas reales de la base SQL de prueba mediante Codex antes de elegir política fiscal; simular separación de POS receipt, documento fiscal y reconciliación de statement.


**Actualización evidencia 10 (Codex):** las 9,792 transacciones POS analizadas tienen recibos únicos; las tablas de statements y facturas contabilizadas tienen 0 filas, así que no demuestran momento de emisión de factura ni ciclo de cierre. [AUD-006 actualizada](../Auditorias/AUD-2026-11-06-006-ls-central-statement-y-numeracion.md). **G-NUM sigue abierto**; diseñar una prueba aislada de tiempos de asignación y reconciliación. 

## Compuerta de entrada inmediata

**Estado actual: F0 PENDIENTE de ejecución**, aunque AUD-004 adelantó evidencia estática. El primer trabajo autorizado por este documento es **auditoría read-only de diferencia entre código versionado y esquema realmente aplicado** y un reporte de línea base. No aprobar fases futuras por silencio; avanzar solo tras confirmación del usuario.

