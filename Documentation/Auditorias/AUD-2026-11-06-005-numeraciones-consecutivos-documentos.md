# AUD-2026-11-06-005 — Numeraciones, consecutivos y documentos para Kivo mult-terminal y omnicanal

**Fecha:** 2026-11-06 · **Origen:** solicitud de anticipar dependencias no mencionadas de la ampliación a terminales y canales digitales. **Estado:** auditoría estática y diseño de escenarios, no implementación. **Rama inspeccionada:** `develop/backoffice-stabilization-integration`, SHA `7ce5163e0c6e698397dca0f57689966a4b714649`. No se verificó esquema realmente aplicado, normas fiscales de Nicaragua ni entorno productivo; no se corrieron tests.

## 1. Hechos auditados y riesgos

| Componente | Evidencia | Riesgo |
|---|---|---|
| Unicidad de facturas | `supabase/migrations/001_initial_schema.sql`: `invoice_number_settings` por restaurante (`prefix, initial_number, next_number`); `sales` tiene `UNIQUE(restaurant_id,invoice_number)` | Esquema diseñado para una serie global de restaurante; no define series por sucursal, tipo de documento o terminal |
| Reserva local | `lib/features/pos/presentation/bloc/pos_checkout_helpers.dart`: `_prepareInvoiceNumbers` lee `nextInvoiceNumber`, `_commitInvoiceNumbers` actualiza settings después de venta (`syncRemote:false`) | Dos POS con copias del contador pueden expedir mismo número provisional; reserva y consumo separados pueden dejar huecos/reutilizaciones tras error/crash |
| Venta local | `lib/features/pos/presentation/bloc/pos_checkout_handlers.dart` usa `invoiceReservation.invoiceNumbers.single` para venta; otro flujo de consumo de personal utiliza `CP-PEND-<id>` | No equiparar consumo personal a factura fiscal |
| Numeración remota | `supabase/migrations/019_pos_sync_sale_remote_invoice_authority.sql` toma `invoice_number_settings ... FOR UPDATE`, deduplica por `id` o `local_id`, genera número, devuelve `invoice_number`, `original_invoice_number`, `renumbered_invoice` | RPC central parece serializar asignación por restaurante; verificar definición efectiva final tras wrappers 028, 051/052, 056, 065 y rutas alternativas de escritura |
| Envío remoto alternativo | `supabase_sync_remote_sender_sales_part.dart` contiene rama legacy `_upsert('sales', ... invoice_number: salePayload['invoiceNumber'])` | Si aún es alcanzable, podría saltarse autoridad RPC; bloquear/compatibilizar y ensayar |
| Conciliación local | `_deviceRpc` devuelve JSON de respuesta; **no se constató** en archivos principales actualización de `LocalSales.invoiceNumber` tras respuesta remota | Investigar rutas parciales `_pushSaleWithDevice` y procesador de cola: riesgo de PDF con número distinto del remoto. Hallazgo pendiente de verificación, no afirmar defecto demostrado |
| PDF | `sale_invoice_pdf_service.dart` describe **PDF no fiscal** y muestra `sale.invoiceNumber` | No llamarlo factura legal definitiva si contiene número provisional sin verificación de emisión |
| Cierre piloto | `Documentation/PILOT_OPERATION_RESET.md` y migración 015 reinician `next_number` | No reusar series de documentos reales históricos; el inicio serio exige cortar operaciones de piloto y verificar numeración normativa antes de emitir |
| Caja/dispositivo | Migraciones 056, 064, 065 vinculan transacciones a `pos_device_id` | Múltiples cajeros y dispositivos requieren separar ID de operación, cierre, terminal y folio legal |
| Otros documentos | Migración 044 `payroll_payment_receipts` y consumo personal usan conceptos de recibo; otros módulos tienen compras, ajustes, adelantos, devoluciones | No aplicar una sola serie de factura a documentos operativos heterogéneos |

## 2. Modelo recomendado de identidad documental

Separar, como conceptos independientes:
- `order_id` UUID de pedido, estable offline y entre canales.
- `order_number` identificador operativo legible (con namespace/sucursal/fecha o secuencia propia); puede coexistir con número de cocina/KOT.
- `sale_id` UUID de transacción de venta y `sale_document_number` / número interno cuando proceda.
- `invoice_id` UUID de documento fiscal/comprobante y **`invoice_number` definitivo**, cuya emisión debe seguir ley y configuración aprobada.
- `payment_id`, `refund_id`, `cash_session_id`, `stock_movement_id`, `purchase_document_id`, `credit_note_id`: identidad propia; no multiplicar numeraciones visibles sin necesidad.
- `origin_channel`, `terminal_id`, `location_id`, `series_id`, `business_date` en contexto de cada evento cuando aplique. Origen web o APP no presupone modalidad o serie fiscal.

**Contrato conceptual:** `document_series(id, restaurant_id, location_id?, document_kind, code/prefix, scope, next_value, effective_from/to, status, version)`, `document_number_assignment(id, series_id, document_id, number, state, assigned_at, issued_at, canceled_at, idempotency_key, terminal_id?, reservation_id?)`. Índices de unicidad compuestos, trazabilidad/auditoría, permisos de asignación, cambios de serie no reescriben números emitidos. El número es propiedad del documento, no del cajero que lo creó.

**No decidir aún** numeración fiscal por sucursal, por terminal o centralizada: requiere confirmar reglas locales/regulatorias, tipo de comprobante, modalidad offline, establecimientos, autorización de talonarios y necesidades reales. La serie interna puede ser distinta de la fiscal.

## 3. Dos estrategias offline a simular antes de decidir

**A. Folio fiscal definitivo central online:** POS offline registra pedido/venta con UUID y recibo provisional **no fiscal**; al sincronizar se emite factura definitiva y se concilia impresión, cliente e historial. Posible impedimento normativo/operativo si la venta debe facturarse inmediatamente sin Internet.

**B. Bloques de folios reservados:** backend asigna rangos exclusivos por serie/terminal con vigencia y ledger; POS puede emitir offline dentro del bloque, sin superposiciones. Exige manejo de bloques agotados, pérdida de dispositivo, revocación, reemplazo, folios no utilizados, huecos justificados, secuencias y eventuales requisitos legales. No usar bloques sin aval fiscal y prueba de concurrencia.

**Alternativa C:** numeración separada por terminal/serie si autorizada por la normativa y emisión de factura offline; no asumir que la identificación del terminal autoriza nuevas series fiscales.

## 4. Matriz de riesgo adicional detectada

| Área | Escenario no trivial | Control/prueba requerida |
|---|---|---|
| Concurrencia | Dos terminales cobran al mismo segundo | Unicidad + asignación atómica de folio o rangos no solapados |
| Offline | Terminal A y B desconectadas con mismo cursor | UUID y comprobante temporal; no dos facturas definitivas iguales |
| Reintento | RPC asigna número y respuesta se pierde | Reenviar misma clave: devolver **mismo** folio y documento sin consumir otro |
| Cancelación | Se anula factura emitida | Conservar folio y registro de anulación; devolución/nota crédito separada según reglas aplicables |
| Impresión | Se imprime PDF antes de sincronización y después | Etiqueta provisional, número confirmado e historial de reimpresiones |
| Split/merge | Una mesa se divide en tres cuentas, luego hay pago mixto | Determinar exactamente cuántos documentos se emiten, sin reservar folios prematuramente |
| Pedido web/QR | Se genera orden sin pago; caja factura al recoger | No asignar factura al añadir al carrito; evitar doble emisión web y POS |
| Pedido programado | Pedido creado hoy, cobrado mañana | Fecha de operación vs emisión y serie vigente documentadas |
| Delivery | Orden pagada online y devuelta parcialmente | Idempotencia de cobros, captura, refund y documento correctivo |
| Caja | Dos cajas del mismo cajero, múltiples turnos | Separación dispositivo/sesión/serie; cierres e informes con mismo corte comercial |
| Sucursal | Tienda nueva, terminal trasladada, venta de otra sucursal | Serie y scope correctos; nunca reasignar folios históricos |
| Seguridad | Usuario modifica próximo número o prefijo con órdenes pendientes | Permiso explícito y restricción de serie; impedir retroceso/colisión |
| Cierre de piloto | Reset de contadores mientras hay ventas offline pendientes | Congelar/revocar colas antiguas y separar serie de piloto de emisión real; respaldo y verificación legal |
| Hora | Venta cerca de medianoche, turno hasta 02:00 | Diferenciar timestamp UTC, fecha de negocio y fecha fiscal de emisión |
| Evolución | Diferentes tipos de documento y jurisdicciones | Catalogar series por `document_kind`, motor desacoplado; no usar `invoice_number` para todo |
| Integraciones | Tercero envía su número de pedido | Guardar número externo como referencia, sin suplantar folio Kivo |
| Control de acceso | RLS/SECURITY DEFINER con `restaurant_id` cliente | Scope derivado de identidad y validación en servidor |
| Backup/restore | Se restaura copia antigua con folios ya utilizados | Contador/ledger monotónico y reconciliación externa antes de emitir |
| Observabilidad | Hueco o duplicado aparente | Auditoría de reserva, asignación, emisión, cancelación y recuperación |
| Retención | Facturas legalmente relevantes | No incluirlas en limpieza indiscriminada del piloto si existió emisión real |

## 5. Correcciones obligatorias al plan de terminales

Agregar **gate G-NUM** previo a F2/F3: auditar definición RPC efectiva, rutas de escritura directa, conciliación del folio remoto a Drift, contexto de emisión, secuencia y PDF; revisar políticas fiscales/documentales aplicables con fuente oficial o asesor autorizado. Ninguna implementación de terminales puede concluir el contrato de ventas sin decidir autoridad y ciclo de emisión.

### Simulador de numeraciones antes de migrar
Crear simulación independiente con dataset sintético (sin SQL productivo): 2 sucursales, 5 terminales, 3 canales, 50 ventas concurrentes, offline A/B, caída luego del commit remoto, segundo intento idempotente, anulación, división de cuenta, cambios de terminal y restauración. Medir: duplicados definitivos = 0, ventas extraviadas = 0, doble emisión = 0, inconsistencias local/remoto = 0 tras reconciliación; folios sin uso trazados y justificados.

**G-NUM se rechaza** si falta ruta de reimpresión corregida, si hay dos autoridades que asignan facturas definitivas, si el POS puede imprimir provisional como definitivo sin advertencia o si no se demuestra idempotencia.

## 6. Alcance y próximos pasos

La auditoría se basó en código y documentación versionada. No demuestra comportamiento fiscal real de Kivo ni conformidad legal. **No se ejecutó** SQL, simulación, Flutter, cambios de código, despliegue o limpieza de datos. Siguiente: ampliar F0 con inventario completo de numeración y verificación de funciones efectivas; diseñar y correr el simulador sintético antes de aprobar migraciones, y contrastar obligaciones fiscales de la jurisdicción de uso.

**Resultado:** numeración de documentos es dependencia **crítica y bloqueante**, no una tarea cosmética posterior al diseño de terminales.
