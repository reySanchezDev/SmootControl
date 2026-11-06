# AUD-2026-11-06-006 — LS Central: transacción POS, recibo, statement y factura

**Fecha:** 2026-11-06. **Estado:** investigación documental oficial + cotejo de mapa de SQL Server, pendiente de validación de comportamiento en la instalación de prueba. Solo documentación, sin ejecución de SQL/código.

## Hipótesis del usuario
«LS Central numera las facturas al hacer statement». **Resultado:** no es una regla universal. LS registra la transacción POS y su `Receipt No.` antes del statement; el statement agrupa y contabiliza. Cuándo se genera un documento fiscal y qué serie utiliza depende del tipo de operación, la localización y la configuración. No equiparar número de transacción, recibo, factura y statement.

## Documentación oficial contrastada

1. [LS Transaction Header](https://help.lscentral.lsretail.com/Content/Fields/T_99001472.htm): el POS genera automáticamente transacciones; sirven como base del Statement y reciben el número de statement cuando se calcula.
2. [LS Statement](https://help.lscentral.lsretail.com/Content/Fields/T_99001487.htm) y [Calculating and Posting Statements](https://help.lscentral.lsretail.com/Content/LS-Retail/Safe-Management/Calculating-And-Posting-Statements.htm): procedimientos de creación, cálculo y contabilización por tienda y método de cierre; los resultados contables no equivalen al recibo POS.
3. [LS Posted Statement No.](https://help.lscentral.lsretail.com/Content/Fields/T_99001485_1.htm): número de statement proviene de **su propia serie**.
4. [LS España Statement Posting](https://help.lscentral.lsretail.com/Content/Localization/ES/Statement-Posting-Spain.htm) y [Retail Setup España](https://help.lscentral.lsretail.com/Content/Localization/ES/Retail-Setup-Spain.htm): ejemplo **específico de España**, con series por tienda/tipo; cuando está activo `Use Document Store Serial No.` el número legal se asigna **al insertar la transacción**, después se utiliza en G/L durante el statement. No extrapolar regla española a Nicaragua.
5. [LS hotfix 27.0](https://help.lscentral.lsretail.com/Content/Hotfixes/Hotfixes-27-0.htm): colisión de `Receipt No.` por suspender/recuperar transacciones, contador retrocediendo. [LS hotfix 26.1](https://help.lscentral.lsretail.com/Content/Hotfixes/Hotfixes-26-1.htm): corrección de huecos en serie de statements. Relevante para simulaciones de Kivo.
6. [Microsoft BC No. Series](https://learn.microsoft.com/en-us/dynamics365/business-central/ui-create-number-series): series documentales, restricciones de continuidad y auditoría. [Microsoft Number sequences](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-number-sequences): una secuencia SQL genérica puede dejar huecos, no confundir con serie documental.

## Evidencia de la BD de prueba (mapa elaborado por Codex)
Documento Drive `05-ventas-y-transacciones.md`, ID `1S-CIB9VhywlmJA8jWOSCLTaHIZ7yyL17`: `LSC Transaction Header` utiliza PK `Store No_, POS Terminal No_, Transaction No_` y campos `Receipt No_`, `Sales Type`, `Entry Status`, `Items Posted`, `Shift No_`, `Date/Time`; líneas de venta comparten misma PK + `Line No_`. **No hay aún evidencia de cuál es el número fiscal definitivo de Casa del Café ni en qué evento se genera**.

## Arquitectura propuesta superior para Kivo (hipótesis a simular, no decisión fiscal)

Separar e identificar:
- `order_id`: UUID operativo y origen/canal inmutable; referencia simple y visible para mesa, cocina, QR/web.
- `pos_transaction_id`: UUID transacción pagada, con `terminal_id`, operador, caja, pagos, importes y snapshot.
- `receipt_number`: referencia de comprobante POS; documento de pago, no necesariamente fiscal.
- `statement_id`: agrupación *operativa/contable* de transacciones por sucursal, caja/turno y fecha, para reconciliar pagos y stock. **No forzar** a que facturar dependa del statement.
- `fiscal_document_id`/serie/folio/tipo: emisión legal cuando corresponda, con política explícita validada; puede ocurrir al pago, al emitir factura, o en cierre dependiendo del marco legal. `credit_note` y `return` con reglas propias.

Principio: el statement **no puede cambiar el número ya entregado al cliente**. Debe vincular transacciones y documentos mediante IDs estables, reconciliar, contabilizar y exhibir excepciones. Si el recibo es provisional, debe decirlo inequívocamente. Historial de emisión, asignación, anulación/reimpresión, razón de huecos, idempotencia, nunca reciclar folios legales.

**Evitar una falsa equivalencia:** Kivo no es todavía un ERP contable; incorporar concepto de cierre/reconciliación `statement` no obliga a implementar G/L contable completo. Priorizar conciliación de caja, pagos, ventas, movimientos e integraciones; futura contabilidad con adaptador y eventos.

### Simulaciones antes de decidir
- Venta POS pagada offline, recibo provisional, sincronización diferida; online, recibo final, eventual invoice según política.
- Dos terminales con IDs y números de recibo propios; mismo restaurante con fiscal central o series autorizadas.
- Suspender/recuperar orden, devolver y resuspender; la serie no retrocede ni reutiliza un recibo.
- Statement calculado con 100 ventas, cierre fallido y reintento: mismos IDs, sin doble contabilización ni cambios de números.
- Venta después de cerrar caja, shift cruzando medianoche, transacciones rezagadas y diferencias de pago.
- Refund, anulación, nota crédito, split ticket, pedido web entregado/cobrado en terminal.
- Reimpresión POS tras conciliación remota, factura ya entregada no cambia folio.
- Condiciones de emisión/documentación fiscal de Nicaragua: verificación independiente oficial antes de aprobar estrategia.

## Indagación SQL pendiente para Codex (solo lectura)
A. Localizar tablas `LSC Transaction Header`, `LSC Statement`, `LSC Posted Statement`, `LSC Trans_ Sales Entry`, `LSC Store`, `LSC POS Terminal`, `No_ Series` y `No_ Series Line` con extensiones físicas; encontrar campos de `Receipt No.`, `Document No.`, `Invoice No.`, `Statement No.`, `Posting Status`, `Transaction No.`. No asumir una tabla de factura sin corroborarla.
B. Crear cadena de relación (solo agregados anonimizados) desde transacción → recibo → statement calculado/contabilizado → ledger/documento, identificando cuando aparece cada número. Si la BD solo muestra estado final, señalar que **no prueba momento de asignación**.
C. Verificar configuraciones de numeración por tienda y terminal y las series efectivamente usadas (conteos por serie, sin códigos de negocio privados). Identificar si hay números fiscales distintos de números POS, y si hay statements vacíos o gaps, sin atribuir automáticamente defectos.
D. Distinguir facturación directa a cuenta del cliente y tickets POS; no afirmar que toda transacción genera factura posted.
E. Guardar informe `10-numeracion-pos-statement-facturacion.md` en misma carpeta Drive, reportando consultas SELECT, claves, conteos, diagramas y dudas; no exponer clientes, empleados, importes individuales ni secretos.
F. No escribir/ejecutar DML, DDL, posting ni operaciones fiscales. No pedirle a Codex modificar la instancia productiva (aunque el servidor se llame «prueba»).

## Gate antes de implementación de terminales
**G-NUM** de [plan de terminales](../Planes/PLAN-2026-11-06-TERMINALES-POS-FASES-AUDITABLES.md) sigue bloqueado hasta elegir política probada. No asumir que emitir al statement es mejor; tampoco imponer asignación de folio fiscal al cobrar. Delimitar documento fiscal vs recibo POS según normativa local y operacional, revisar definiciones del servidor real y simular reconciliación.
