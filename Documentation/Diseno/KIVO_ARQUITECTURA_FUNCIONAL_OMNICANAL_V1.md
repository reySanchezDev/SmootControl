# KIVO — Diseño funcional omnicanal y Centro de Artículos (V1)

**Fecha:** 2026-11-06. **Estado:** propuesta de arquitectura para revisión, NO implementación aprobada. **Alcance:** restaurantes de mesa, cafeterías, panaderías, locales de comida rápida, food trucks, dark kitchens y demás comercios de alimentos. Preparar la plataforma para pedidos web/QR, app de clientes y repartidores, delivery propio y terceros.

Referencias: auditorías [001](../Auditorias/AUD-2026-11-06-001-maestro-articulos.md), [002](../Auditorias/AUD-2026-11-06-002-dependencias-y-migracion-articulos.md), [003](../Auditorias/AUD-2026-11-06-003-referencia-ls-central-drive.md), [reglas de negocio](../BUSINESS_RULES.md), [recetas e inventario](../RECETAS_MATERIA_PRIMA_PLAN.md).

## 1. Objetivo y reglas innegociables

- **Experiencia simple sobre dominio robusto:** una pantalla principal de Artículos y una ficha contextual, sin catálogo separado por cada tipo físico ni pasos escondidos en «… Más».
- **Misma autoridad de órdenes y precios para todos los canales:** POS, mesero, QR, web, app, integración de terceros, llamada/carga manual; el cliente web/app jamás usa directamente la base POS local.
- **Origen de orden obligatorio e inmutable en cuanto a procedencia inicial**, con historial de cambios posterior y correlación externa. Nunca deducir el origen a partir del tipo de entrega.
- **Separar origen/canal de modo de servicio**: web + recoger, web + delivery, QR mesa + consumir aquí, POS + llevar, tercero + delivery, etc.
- Integridad transaccional, aislamiento por restaurante/sucursal, historial y snapshots; eventos idempotentes y offline-first en POS.
- Los datos operativos del piloto y saldos antiguos no necesitan conservarse. **Sí** preservar productos, precios, recetas, empaques, modificadores y configuración útil. El borrado/cutover será una operación futura **expresamente autorizada**, no parte de este diseño.

## 2. UX: Centro de Artículos

Una lista filtrable: Todos / Venta / Ingredientes / Empaques / Preparaciones / Servicios. Una sola identidad de artículo, con capacidades independientes (vendible, receta, stock, compras, personalizable, publicación por canal); no inferir capacidad solo del tipo. Código, nombre, estado, precio y disponibilidad visibles. Selección + barra de acciones explícitas.

**Ficha única con configuración progresiva**: Identidad → Venta/precio/impuestos → Receta/variantes → Opciones/modificadores → Empaque/consumo → Inventario/unidades/compras → Disponibilidad por canal/sucursal/horario → Vista previa POS/QR/web. Solo presentar secciones pertinentes, sin crear siete pantallas separadas. Permitir plantillas «Cafetería», «Hamburguesería», «Restaurante», «Panadería», sin imponer límites de negocio.

Los configuradores reutilizables (grupos de opciones, impuestos, listas de precios, horarios, unidades) podrán tener administración masiva cuando haya necesidad real; evitar duplicidad de datos maestros.

## 3. Identidad y procedencia de órdenes: CONTRATO PRINCIPAL

Cada orden debe registrar, desde su creación, como mínimo:

| Campo lógico | Regla |
|---|---|
| `order_id` | UUID global estable, también offline |
| `tenant_id` / `restaurant_id`, `location_id` | Obligatorios; seguridad y ámbito |
| `origin_channel` | Código **inmutable**: `pos`, `waiter`, `table_qr`, `web`, `customer_app`, `delivery_partner`, `phone`, `admin`, `integration`. Catálogo extensible; no imponer lista cerrada en clientes |
| `origin_source_id` | Identificador del terminal, sitio, app, integración o partner que inició la orden |
| `origin_actor_id` | Usuario/cliente/operador cuando corresponda; permitir invitado seguro |
| `origin_device_id` y `origin_session_id` | Opcionales según canal, obligatorios por política en POS |
| `external_order_id` / `external_provider` | Referencia única por proveedor/tenant para pedidos de terceros |
| `service_mode` | `dine_in`, `takeaway`, `pickup`, `delivery`, `drive_thru` u otro extensible; **independiente del canal** |
| `fulfillment_mode`, `fulfillment_group_id` | Permiten pedido mixto o cumplimiento por líneas en futuro |
| `table_id`, `qr_session_id` | Solo si aplica; QR verificable, sin exponer IDs adivinables |
| `created_at_utc`, `accepted_at_utc`, `business_date`, `time_zone` | Auditoría, corte local de negocio, horario de tienda y programación |
| `client_request_id` / `idempotency_key` | Deduplicación de reintentos offline y online |
| `schema_version`, `pricing_snapshot_version` | Compatibilidad y reproducibilidad |
| `status`, `status_version`, `revision` | Máquina de estados con concurrencia optimista |
| `origin_metadata` | Campos adicionales tipados y validados; nunca sustituye columnas clave ni almacena secretos |

**Modelo de procedencia enriquecida:** `order_source_event`/historial (creación, transferencia, edición, reenvío, cambio de canal de atención). Preservar origen original aunque un pedido web sea editado por caja. No confundir `created_by`, `accepted_by`, `prepared_by`, `delivered_by` con `origin_channel`. El POS debe mostrar badges claros de origen, pero no depende de su presentación para lógica de negocio. Filtros y reportes por canal, modo, sucursal, operador, tipo de entrega y proveedor.

**Ejemplos:** POS/tableta → `pos + dine_in`; QR en mesa → `table_qr + dine_in`; sitio para recoger → `web + pickup`; app cliente con repartidor → `customer_app + delivery`; pedido telefónico que carga cajero → `phone + delivery`; agregador → `delivery_partner + delivery`. QR puede tener origen QR aunque mesero finalice el cobro.

## 4. Núcleo de dominio (esquema lógico, no SQL aprobado)

- `item`, `item_unit`, `item_price`, `item_capability`, `item_availability`, `menu_publication`, `item_media`. Multi-sucursal, moneda e impuestos; disponibilidad específica por franja/canal.
- `recipe`, `recipe_version`, `recipe_component` con merma, rendimiento, unidad y prevención de ciclos. `modifier_group`, `modifier_option`, `item_modifier_assignment`; selección obligatoria, min/max, multiselección, incompatibilidades y valores por defecto.
- Modificador **instrucción** (p. ej. bien cocido), **exclusión** (sin azúcar), **adición** (extra queso), **sustitución** (leche vegetal), **porción/variación**. Si hay receta, los ajustes afectan consumo con reglas deterministas; si no hay ingrediente presente, validar en lugar de restar inventario arbitrario.
- `service_mode`, `sales_channel`, `packaging_rule` o `consumption_rule`: empaque como artículo real, regla por producto/variante/modo/canal/sucursal y paquete por línea o por pedido. Una sola autoridad que computa consumo para evitar dobles rebajas.
- `order`, `order_line`, `order_line_modifier`, `order_line_component_snapshot`, `order_line_packaging_snapshot`, `order_event`. Mantener variantes, precios, impuestos, descuentos, alergénicos declarados, observaciones, versión de receta y reglas efectivamente aplicadas.
- `kitchen_ticket`, `kitchen_ticket_line`, `kitchen_station`, `fulfillment`, `pickup_handoff`; cocina independiente de cobro/recibo; soporte KDS e impresoras con deduplicación.
- `payment_intent`, `payment`, `refund`, `sale`, `receipt`, `cash_session`; servicio no equivale a pago ni al origen. Pago parcial/anticipado/contraentrega/tips sujetos a reglas.
- `inventory_movement`, `inventory_balance`, `inventory_location`, `purchase`, `stock_count`; inventario derivado de eventos con costo/unidad histórica. No invertir consumos recalculando recetas actuales.
- `delivery_job` separado, más adelante: área/cobertura, costos, asignación, prueba de entrega, intentos fallidos, conductor, ubicación y privacidad, sin acoplar la venta a un proveedor.
- `outbox`, `inbox_deduplication`, `external_integration`, `audit_event`; contratos versionados e idempotentes.

## 5. Matriz de escenarios que deben diseñarse y probarse

| Familia | Casos que debe cubrir |
|---|---|
| Tipos de negocio | servicio a mesa, mostrador, autoservicio, food truck, panadería por peso/unidad, cafetería por tamaños, bar de bebidas, dark kitchen, varias cocinas |
| Producto | simple, elaborado, subreceta, combo, menú ejecutivo, pizza ½ y ½, tamaños, complementos, variantes, venta por peso, productos agotados |
| Modificadores | sin azúcar/cebolla, extra ingrediente, sustitución, cocción, hielo, niveles de picante, alergias, min/max/default, repetición por cantidad y combinaciones inválidas |
| Empaques | caja por plato, vaso por bebida, bolsa por pedido, servilleta por ítem, delivery contra pickup, unidad y costo, devoluciones; evitar doble consumo |
| Venta | mesa, cuenta separada, cuentas compartidas, pedidos por ronda, cambios, descuentos, combos, promociones, impuestos, propina, cancelación parcial, devolución y reembolso |
| Omnicanal | POS offline, mesero, QR mesa, sitio web pickup/delivery, app de cliente, pedidos telefónicos, app repartidor, marketplace externo, integración API |
| Captura del origen | origen inicial inmutable, terminal/QR/app/proveedor, quién confirmó, quién modificó, ID externo, correlación, trazabilidad y reportes filtrables |
| Tiempo y capacidad | múltiples zonas horarias comerciales, turnos, cierre, horarios por canal, pedidos programados, tiempos estimados, límites de órdenes simultáneas |
| Cocina | estaciones, notas, alérgenos (aviso, no garantía), tickets KDS/KOT, reimpresión, parcial, retrasos, cancelaciones mientras se prepara |
| Fulfillment | comer aquí, para llevar, pickup, drive-through, delivery, pedido mixto, entrega parcial, conductor propio/tercero, prueba de entrega |
| Pagos | cobro en POS/online/contra entrega, efectivo, tarjeta, transferencia, pagos mixtos, fallidos/reintentados, reembolsos parciales y conciliación |
| Concurrencia | dos terminales en la misma mesa, cambio de precio mientras carrito abierto, doble clic, mismo pedido recibido dos veces, pedidos offline al reconectar |
| Inventario | unidades y decimales, agotados, artículos sin control, materia prima negativa según política, devolución, ajustes, trazabilidad por sucursal |
| Seguridad | tenant/RLS, autorización de canal/rol, endpoint QR público seguro, rate limiting, abuso/spam, logs sin PII innecesaria, aislamiento por sucursal |
| Experiencia | mensajes claros, configuración guiada, accesibilidad, idioma/moneda, errores recuperables, acciones explícitas sin menús ocultos |
| Operación y escalabilidad | API backward compatible, observabilidad, eventos reintentables, sincronización multi-dispositivo, backups/restore, gestión de versiones y rollout |

**No equivalen a funcionalidades aprobadas para el primer lanzamiento.** Son exigencias a considerar para que las decisiones actuales no bloqueen su incorporación futura.

## 5A. Disponibilidad comercial temporal, estacional y contextual — requisito esencial

**Decisión de producto:** la disponibilidad comercial de un artículo NO es sinónimo de `is_active`, ni del stock actual, ni del horario de apertura. Se calcula con reglas explícitas, reutilizables, versionadas y auditables; debe funcionar igual en POS, QR, web, app de cliente e integraciones. Las configuraciones pueden existir antes de que se implemente cada canal.

### Escenarios indispensables

| Escenario | Regla de ejemplo | Resultado esperado |
|---|---|---|
| Desayuno | Lunes-viernes 06:00–11:00, sábados-domingos 07:00–12:00 | Fuera de horario no aceptar nuevas líneas; pedidos existentes permanecen auditables |
| Almuerzo/cena | 11:00–15:00 / 17:00–22:00, incluida ruptura entre turnos | Visibilidad y capacidad de pedido distintas |
| Franja que cruza medianoche | Viernes 20:00–sábado 02:00 | Interpretar ventana por día de inicio, sin cortar a 00:00 |
| Temporada fija | Mango: 15 marzo–30 junio de un año, según cada negocio | Activación futura y expiración automática, sin borrar artículo |
| Temporada recurrente anual | Mango: marzo–junio cada año | Ventana anual configurable; **no asumir** disponibilidad por clima real |
| Temporada variable | Administrador habilita/deshabilita cosecha por campaña | Estado manual con inicio/fin opcionales y precedencia explícita |
| Fechas especiales | Navidad, Semana Santa, feriado local, evento o aniversario | Sobrescribir horarios regulares mediante excepción fechada |
| Sucursal | Desayuno en sucursal A, no disponible en B | No confundir catálogo global con publicación por local |
| Canal | Disponible en salón, no en delivery; promo exclusiva QR | Publicación filtrada; un canal no filtra disponibilidad de otro |
| Modalidad | Smoothie para llevar con presentación distinta; delivery con empaque obligatorio | Aplicar reglas de packaging y precio después de elegibilidad |
| Stock/ingrediente agotado | Temporada activa, pero no hay mango | Marcar **agotado temporalmente**, sin desactivar campaña |
| Capacidad | Solo 30 unidades al día o capacidad limitada de cocina | Cupo y reservas consistentes bajo concurrencia; no usar flag estático |
| Preparación | Cocina de desayunos cierra 10:45 para órdenes nuevas | Distinguir ventana de **admisión**, preparación y entrega |
| Pedidos anticipados | Solicitar hoy para mañana a las 09:00 | Evaluar disponibilidad en hora de cumplimiento y reglas de anticipación |
| Variantes | Tamaño grande solo de 09:00–12:00; toppings por campaña | La regla puede afectar SKU/variante/grupo, no solo producto padre |
| Menú completo | Menú de desayuno agrupa varios artículos con restricciones propias | Componer disponibilidad del menú y componentes; no crear copias de producto |
| Suspensión urgente | Agotado, equipo averiado, cierre de cocina, alerta de alérgenos | Suspensión inmediata, visible en todos los canales conectados |
| Horarios con zona | Sucursal en otro país o zona horaria; cambio de hora | Evaluar en zona IANA de sucursal, persistiendo instantes UTC |

### Diseño UX: no multiplicar pantallas
Dentro de la ficha de artículo incluir una sección **«Disponibilidad»** con controles claros:
- `Siempre disponible` (valor predeterminado cuando no exista ninguna restricción).
- `Por horario`: días de la semana + franjas con apertura/cierre.
- `Por temporada`: intervalo de fechas único, repetición anual u opción **«Activación manual»**.
- `Reglas adicionales`: sucursal, canal, modalidad, variante, cupo diario y calendario de excepciones.
- `Pausar temporalmente`: suspender pedidos sin editar la programación normal, con motivo y fecha de restablecimiento opcional.
- **Vista previa** visible: «Disponible ahora / No disponible / Próxima disponibilidad», comprobable por sucursal, canal y fecha/hora. Para administradores, mostrar cuál regla bloquea la venta.
- Plantillas reutilizables (Desayunos, Almuerzos, Temporada de mango, Fin de semana), seleccionables al configurar uno o varios artículos; administrar plantillas desde el mismo editor, no obligar a abrir catálogos separados.
- Para POS y clientes, comunicar una razón sencilla y consistente: «Disponible desde las 6:00 a. m.», «Solo por temporada», «Agotado hoy» o «No disponible para delivery». Las restricciones relevantes deben ser explícitas; no ocultarlas tras menús «Más».

### Esquema lógico propuesto (NO migración)

```text
availability_policy
  id, restaurant_id, name, is_active, version, priority
availability_rule
  id, policy_id, rule_kind (weekly_window|date_range|annual_season|exception|manual|quota)
  timezone_source, day_of_week, start_local_time, end_local_time
  valid_from, valid_until, annual_start_month_day, annual_end_month_day
  allow_or_block, priority, rule_payload_validated
availability_assignment
  policy_id, target_type (item|variant|modifier|menu), target_id
  location_id?, channel_id?, service_mode_id?
availability_override
  target_id, location_id?, channel_id?, reason_code
  blocked, starts_at_utc, ends_at_utc?, created_by, created_at
availability_capacity
  target_id, location_id, service_date, limit_quantity, reserved_quantity, consumed_quantity
order_line_eligibility_snapshot
  order_line_id, evaluated_at_utc, requested_fulfillment_at_utc
  policy_version, decision, reason_code, rule_ids
```

**Nota:** esta es la forma funcional mínima para discusión; evitar una tabla por cada caso si una política con reglas tipadas resuelve el requisito. No usar JSON opaco sin validaciones, índices, autorización y reglas de consistencia.

### Semántica obligatoria del motor de elegibilidad

1. Evaluar en este orden: existencia del artículo y restaurante → estado activo → publicación por sucursal/canal → horario del negocio y estación de cocina → suspensión urgente → bloqueos explícitos/fechas especiales → temporada vigente → día/franja habilitada → variante/opciones → inventario/cupo → posibilidad de fulfillment. **Un bloqueo explícito de seguridad/cocina prevalece sobre permisos ordinarios.**
2. Distinción de respuestas: `visible`, `orderable_now`, `orderable_for_requested_time`, `next_available_at`, `reason_code`. Un artículo estacional puede aparecer como «Próximamente» sin poder añadirse al carrito. La política de mostrar u ocultar debe ser configurable.
3. Toda validación de disponibilidad para pedido se repite **en el servidor al confirmar**; no basta deshabilitar un botón en UI. Para POS offline usar políticas cacheadas con versión y reglas de caducidad/gracia; registrar aceptación offline y resolver conflictos al sincronizar sin crear ventas duplicadas.
4. El instante decisivo se define por canal y operación: pedido inmediato → momento de aceptación; programado → horario solicitado de preparación/entrega; pedido iniciado antes del cierre pero enviado después → validar al enviar. Evitar cobros por órdenes que no pueden cumplirse (o gestionar captura/autorización diferida y compensaciones).
5. Guardar snapshot de regla efectiva y horario solicitado en la línea; cambios posteriores de temporada o precio no pueden alterar retroactivamente la venta. Para aumento de cantidad, cambio de producto u horario, revalidar solamente la parte modificada.
6. Política de conflictos clara: excepción fechada > semanal ordinaria; bloqueo urgente > habilitación temporal; políticas de alcance más específico (variante/sucursal/canal) deben tener resolución determinista documentada. No usar «la última regla que llegó gana».
7. Validar intervalos cerrados-abiertos `[inicio, fin)`, cruces de medianoche, leap day, límites anuales que cruzan diciembre, duplicación de ventanas, DST y cierre de negocio que excede 24:00; los días calendario se calculan con `business_date` por sucursal.
8. Cupos simultáneos requieren reserva/reducción transaccional y expiración, con idempotencia por `order_id`; **no prometer inventario o cuota global estricta con POS offline** sin protocolo de reservas o límites exclusivos por dispositivo.
9. Grupos de modificadores/recetas: si «leche de almendra» está fuera de temporada, la opción se oculta/deshabilita, pero se puede vender la bebida con otras opciones; sustituciones deben revalidar elegibilidad y consumo sin doble descuento.
10. Historial operativo: registrar quién creó/cambió calendario, cuándo entró en vigor, de qué versión provino la decisión y motivo de rechazo; separar reportes de ventas reales de demanda rechazada, respetando privacidad.

### Casos de aceptación iniciales

- A las 10:59 desayuno elegible y 11:00 deja de aceptar nuevas órdenes, con límites definidos por zona y sucursal.
- Temporada de mango recurrente se habilita cada año y puede pausarse manualmente por falta de materia prima, sin borrar ni duplicar el artículo.
- Orden web programada para mañana 09:00 es válida aun si el producto no es vendible en el momento de crearla, según reglas de anticipación.
- Cambio de temporada durante pago se revalida; no cobrar dos veces al reintentar.
- POS offline con calendario cacheado funciona y sincroniza sin duplicados; reglas antiguas se registran en snapshot y conflicto es resoluble.
- Variantes, combos, opciones y empaques usan el contexto correcto de canal, sucursal y modalidad.
- Suspensión por mantenimiento de cocina bloquea nuevos pedidos pero conserva las órdenes ya aceptadas y crea tareas de excepción si no pueden completarse.
- Un feriado sobrescribe las franjas de desayuno sin modificar los horarios semanales de los días siguientes.

**Alcance inicial recomendado:** disponibilidad semanal, fechas/temporada, sucursal y canal, suspensión temporal y vista previa. Preparar contratos para cupos, pedidos programados y canal público, sin declarar esas capacidades ya implementadas.

## 6. Reglas técnicas indispensables

1. **Una única máquina de estados** con transiciones autorizadas: borrador → enviada → aceptada → preparación → lista → entregada/completada; cancelación/rechazo/reembolso modelados aparte y según estado. Pago y cocina evolucionan en estados independientes.
2. **Un identificador de orden estable**, código visual por sucursal distinto de UUID técnico. Idempotencia por tenant + canal/proveedor + referencia externa o clave de petición; mantener el mismo ID al reintentar.
3. **Offline-first POS** usa cola duradera con orden causal, reconciliación y políticas de conflicto; web y app solo envían comandos a API backend con autenticación/validación.
4. **No vender desde precios del dispositivo** sin reglas de confirmación; guardar snapshot final y aplicar resolución de tarifas determinista.
5. **Inventario y anulaciones** referenciados a movimientos originales; no consumir receta más empaque dos veces.
6. **Publicación de catálogo** es proyección pública limitada, nunca exponer secretos, costo interno, compras, permisos ni datos entre restaurantes.
7. **Arquitectura evolutiva:** modular monolith/backends por dominios antes de distribuir microservicios; desacoplar clientes con APIs y eventos, no crear bases duplicadas.
8. **Transición del piloto:** conservar maestros; datos de operaciones y existencias del piloto descartables; sincronización antigua debe quedar aislada antes del reinicio autorizado, sin recobro automático.

## 7. Propuesta de fases (sin fechas ni implementación automática)

- **Diseño:** validar modelo, decisión fuente de orden, invariantes, variantes, pricing, estados y contratos de API; elaborar diagramas/casos de aceptación.
- **Fundación:** catálogo maestro y capacidades; recetas, modificadores y empaques; migración de catálogos existentes en copia.
- **POS estable:** motor de órdenes/ventas, inventario y caja, sincronización y pruebas exhaustivas; cerrar piloto y reinicio controlado.
- **Autoservicio web/QR:** catálogo publicado, carrito, órdenes autenticadas o de invitado, pagos si se habilitan, estados en tiempo real.
- **Delivery:** dispatch, zonas, tarifas, asignación, conductor y tracking, protección de datos.
- **Integraciones:** terceros, marketplaces, fidelización y analítica omnicanal.

## 8. Pendientes de decisión explícita (no bloquear modelado base)
- Qué capacidades entran en primera liberación y cuáles quedan solo preparadas.
- Origen de verdad definitivo para precios/impuestos/inventario al coexistir dispositivos offline y web.
- Política de inventario al agotarse ingrediente y reservas para órdenes web.
- Régimen fiscal local, comprobante y reembolsos aplicables.
- Política de canales, branding, restaurantes/sucursales y franquicias.
- Fecha real y plan aprobado de corte del piloto.

**Próxima acción:** revisión de este diseño con el usuario y matriz de aceptación; después una propuesta de cambios técnicos contra código actual (sin ejecutarlos sin autorización). No afirmar que estos componentes ya existen.
