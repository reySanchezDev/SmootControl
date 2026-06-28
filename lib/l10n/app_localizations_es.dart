// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'SmooControl';

  @override
  String get dashboardTitle => 'Panel operativo';

  @override
  String get dashboardSubtitle =>
      'Base inicial lista para ventas, caja, gastos y sincronización.';

  @override
  String get primaryAction => 'Abrir POS';

  @override
  String get secondaryAction => 'Ver reportes';

  @override
  String get signOutAction => 'Cerrar sesion';

  @override
  String get trackingStatus => 'Estado del proyecto';

  @override
  String get trackingStatusValue => 'Base en preparación';

  @override
  String get offlineFirst => 'Offline-first';

  @override
  String get offlineFirstValue =>
      'La app guardará ventas y gastos localmente antes de sincronizar.';

  @override
  String get responsiveReady => 'Responsivo';

  @override
  String get responsiveReadyValue =>
      'Diseñado para móvil, tablet y web desde el inicio.';

  @override
  String get moduleCatalog => 'Categorías';

  @override
  String get moduleProducts => 'Productos';

  @override
  String get moduleModifiers => 'Modificadores POS';

  @override
  String get modulePaymentMethods => 'Métodos de pago';

  @override
  String get moduleTables => 'Mesas';

  @override
  String get moduleSales => 'Ventas';

  @override
  String get moduleCashRegister => 'Caja diaria';

  @override
  String get moduleExpenses => 'Gastos';

  @override
  String get moduleExchangeRates => 'Tasas de cambio';

  @override
  String get moduleSettings => 'Configuración';

  @override
  String get moduleRoles => 'Roles';

  @override
  String get moduleUsers => 'Usuarios';

  @override
  String get moduleAudit => 'Auditoría';

  @override
  String get moduleSync => 'Sincronización';

  @override
  String get moduleComingSoon => 'Módulo en preparación';

  @override
  String get emptyCatalogTitle => 'Sin categorías';

  @override
  String get emptyCatalogMessage =>
      'Crea categorías y subcategorías para ordenar el POS.';

  @override
  String get emptyProductsTitle => 'Sin productos';

  @override
  String get emptyProductsMessage =>
      'Crea productos para venderlos desde el POS.';

  @override
  String get emptyModifiersTitle => 'Sin modificadores';

  @override
  String get emptyModifiersMessage =>
      'Crea grupos como Bastimento o Guarnicion y agrega las opciones disponibles.';

  @override
  String get emptyPaymentMethodsTitle => 'Sin métodos de pago';

  @override
  String get emptyPaymentMethodsMessage =>
      'Configura efectivo, tarjeta, transferencia u otros métodos.';

  @override
  String get emptyTablesTitle => 'Sin mesas';

  @override
  String get emptyTablesMessage =>
      'Crea las mesas que se usarán en el servicio.';

  @override
  String get emptySalesTitle => 'Sin ventas';

  @override
  String get emptySalesMessage => 'Las ventas registradas aparecerán aquí.';

  @override
  String get salesDateLabel => 'Fecha';

  @override
  String get emptyExpensesTitle => 'Sin categorías de gastos';

  @override
  String get emptyExpensesMessage =>
      'Crea categorías para controlar salidas operativas.';

  @override
  String get posReadyTitle => 'POS en preparación';

  @override
  String get posReadyMessage =>
      'La pantalla de facturación usará categorías, productos, mesas y cuentas separadas.';

  @override
  String get reportsReadyTitle => 'Reportes en preparación';

  @override
  String get reportsReadyMessage =>
      'Aquí se mostrarán ventas, ganancias, gastos, caja y anulaciones.';

  @override
  String get reportPeriodToday => 'Día';

  @override
  String get reportPeriodWeek => 'Semana';

  @override
  String get reportPeriodMonth => 'Mes';

  @override
  String get reportPeriodYear => 'Año';

  @override
  String get reportPeriodCustom => 'Rango';

  @override
  String get reportSelectDate => 'Seleccionar fecha';

  @override
  String get reportSelectRange => 'Seleccionar rango';

  @override
  String get reportRangeLabel => 'Rango';

  @override
  String get reportGrossSales => 'Ventas';

  @override
  String get reportGrossProfit => 'Ganancia bruta';

  @override
  String get reportExpenses => 'Gastos';

  @override
  String get reportExpensesDetail => 'Detalle de gastos';

  @override
  String get reportNoExpenses => 'Sin gastos registrados en este periodo.';

  @override
  String get expenseCategoryFilter => 'Filtrar por categoria';

  @override
  String get allCategoriesOption => 'Todas las categorias';

  @override
  String get reportNetProfit => 'Ganancia real';

  @override
  String get reportAverageTicket => 'Ticket promedio';

  @override
  String get reportSalesCount => 'Ventas registradas';

  @override
  String get reportVoidsCount => 'Anulaciones';

  @override
  String get reportCashSessions => 'Cajas registradas';

  @override
  String get reportVoidsDetail => 'Detalle de anulaciones';

  @override
  String get reportNoVoids => 'Sin anulaciones en este periodo.';

  @override
  String get reportVoidBy => 'Anulada por';

  @override
  String get localUserLabel => 'Usuario local';

  @override
  String get reportTopProducts => 'Productos más vendidos';

  @override
  String get reportLowestProducts => 'Productos menos vendidos';

  @override
  String get reportNoProducts => 'Sin productos vendidos en este periodo.';

  @override
  String get reportUnitsSold => 'unidades';

  @override
  String get activeStatus => 'Activo';

  @override
  String get inactiveStatus => 'Inactivo';

  @override
  String get availableInPosField => 'Disponible en POS';

  @override
  String get availableInPosStatus => 'Disponible en POS';

  @override
  String get unavailableInPosStatus => 'No disponible en POS';

  @override
  String get productOptionGroupsField => 'Opciones para POS';

  @override
  String get productOptionGroupsEmptyMessage =>
      'Agrega grupos solo si el producto debe pedir acompanamientos, bases u otras elecciones.';

  @override
  String get productOptionGroupsFormatError =>
      'Completa el nombre del grupo y al menos una opcion.';

  @override
  String get productModifierGroupsField => 'Grupos modificadores';

  @override
  String get productModifierGroupsEmptyMessage =>
      'Crea grupos en Modificadores POS y luego asignelos al producto.';

  @override
  String get productHasOptionsStatus => 'Pide opciones en POS';

  @override
  String get selectProductOptionsTitle => 'Seleccionar opciones';

  @override
  String get addOptionGroupAction => 'Agregar grupo';

  @override
  String get optionGroupNameField => 'Nombre del grupo';

  @override
  String get optionGroupRequiredField => 'Requerido en POS';

  @override
  String get productOptionField => 'Opcion';

  @override
  String get addOptionAction => 'Agregar opcion';

  @override
  String get skipOptionalOptionAction => 'Omitir';

  @override
  String get removeAction => 'Quitar';

  @override
  String get deleteAction => 'Eliminar';

  @override
  String get nextAction => 'Siguiente';

  @override
  String get previousAction => 'Anterior';

  @override
  String get addToCartAction => 'Agregar';

  @override
  String get cashAffectsRegister => 'Afecta efectivo';

  @override
  String get requiresReference => 'Requiere referencia';

  @override
  String get saleStatusCompleted => 'Completada';

  @override
  String get saleStatusVoided => 'Anulada';

  @override
  String get voidSaleAction => 'Anular';

  @override
  String get voidSaleTitle => 'Anular venta';

  @override
  String get voidReasonField => 'Motivo de anulación';

  @override
  String get saleVoidedMessage => 'Venta anulada.';

  @override
  String get generatePdfAction => 'Generar PDF';

  @override
  String get previewPdfAction => 'Ver comprobante';

  @override
  String get invoicePreviewTitle => 'Vista previa del comprobante';

  @override
  String get pdfGenerationError => 'No se pudo generar el PDF.';

  @override
  String get createAction => 'Crear';

  @override
  String get editAction => 'Editar';

  @override
  String get confirmAction => 'Confirmar';

  @override
  String get cancelAction => 'Cancelar';

  @override
  String get okAction => 'OK';

  @override
  String get saveAction => 'Guardar';

  @override
  String get backAction => 'Volver';

  @override
  String get searchField => 'Buscar';

  @override
  String get emptySearchTitle => 'Sin resultados';

  @override
  String get emptySearchMessage =>
      'No hay registros que coincidan con la busqueda.';

  @override
  String get nameField => 'Nombre';

  @override
  String get categoryTypeField => 'Tipo';

  @override
  String get categoryTypeCategory => 'Categoría';

  @override
  String get categoryTypeSubcategory => 'Subcategoría';

  @override
  String get catalogParentField => 'Ubicar dentro de';

  @override
  String get rootCategoryOption => 'Categoría principal';

  @override
  String get categoryInsideOf => 'Dentro de';

  @override
  String get expandGroupAction => 'Expandir grupo';

  @override
  String get collapseGroupAction => 'Contraer grupo';

  @override
  String get expandedStatus => 'Expandido';

  @override
  String get collapsedStatus => 'Contraído';

  @override
  String get parentCategoryField => 'Categoría';

  @override
  String get priceInCentsField => 'Precio';

  @override
  String get costInCentsField => 'Costo';

  @override
  String get createCategoryTitle => 'Nueva categoría';

  @override
  String get editCategoryTitle => 'Editar categoría';

  @override
  String get removeCategoryLevelTitle => 'Quitar nivel';

  @override
  String removeCategoryLevelMessage(String name) {
    return 'Se eliminara el nivel \"$name\". Sus productos y subniveles directos quedaran dentro del nivel anterior.';
  }

  @override
  String get removeCategoryLevelWithChildrenMessage =>
      'Esta accion no elimina la categoria principal.';

  @override
  String get removeCategoryLevelConfirm => 'Quitar nivel';

  @override
  String get createProductTitle => 'Nuevo producto';

  @override
  String get editProductTitle => 'Editar producto';

  @override
  String get createModifierGroupTitle => 'Nuevo grupo modificador';

  @override
  String get editModifierGroupTitle => 'Editar grupo modificador';

  @override
  String get createModifierOptionTitle => 'Nueva opcion modificadora';

  @override
  String get editModifierOptionTitle => 'Editar opcion modificadora';

  @override
  String get addModifierOptionAction => 'Agregar opcion';

  @override
  String get deactivateAction => 'Inactivar';

  @override
  String get deactivateCatalogItemTitle => 'Inactivar registro';

  @override
  String deactivateCatalogItemMessage(String name) {
    return 'Se inactivara \"$name\". El historico se conserva y no se borra fisicamente.';
  }

  @override
  String get deactivateModifierGroupTitle => 'Inactivar grupo modificador';

  @override
  String deactivateModifierGroupMessage(String name) {
    return 'Se inactivara el grupo \"$name\" y dejara de solicitarse en el POS. Sus opciones se conservan para historico.';
  }

  @override
  String get deactivateModifierOptionTitle => 'Inactivar opcion modificadora';

  @override
  String deactivateModifierOptionMessage(String name) {
    return 'Se inactivara la opcion \"$name\" y dejara de aparecer en el POS.';
  }

  @override
  String get modifierGroupNoOptions => 'Sin opciones';

  @override
  String get modifierGroupOneOption => '1 opcion';

  @override
  String modifierGroupManyOptions(int count) {
    return '$count opciones';
  }

  @override
  String get createPaymentMethodTitle => 'Nuevo método de pago';

  @override
  String get editPaymentMethodTitle => 'Editar método de pago';

  @override
  String get createTableTitle => 'Nueva mesa';

  @override
  String get editTableTitle => 'Editar mesa';

  @override
  String get fieldRequiredError => 'Completa los campos requeridos.';

  @override
  String get numericFieldError => 'Ingresa un número válido.';

  @override
  String get activeField => 'Activo';

  @override
  String get optionalFieldHint => 'Opcional';

  @override
  String get optionalField => 'Opcional';

  @override
  String get yesLabel => 'Sí';

  @override
  String get noLabel => 'No';

  @override
  String get createExpenseCategoryTitle => 'Nueva categoría de gasto';

  @override
  String get editExpenseCategoryTitle => 'Editar categoría de gasto';

  @override
  String get deleteExpenseCategoryTitle => 'Eliminar categoría de gasto';

  @override
  String deleteExpenseCategoryMessage(String name) {
    return 'Se eliminara \"$name\". Si tiene categorias hijas, quedaran en la raiz.';
  }

  @override
  String get createExpenseTitle => 'Nuevo gasto';

  @override
  String get expenseSavedMessage => 'Gasto registrado correctamente.';

  @override
  String get expenseCategoriesSection => 'Categorías de gasto';

  @override
  String get todayExpensesSection => 'Gastos de hoy';

  @override
  String get noExpensesTodayMessage => 'No hay gastos registrados hoy.';

  @override
  String get unknownExpenseCategory => 'Sin categoría';

  @override
  String get amountInCentsField => 'Monto';

  @override
  String get descriptionField => 'Descripción';

  @override
  String get openCashRegisterTitle => 'Abrir caja';

  @override
  String get closeCashRegisterTitle => 'Cerrar caja';

  @override
  String get openingCashField => 'Efectivo inicial';

  @override
  String get closingCashField => 'Conteo físico';

  @override
  String get cashOpeningAmount => 'Efectivo inicial';

  @override
  String get cashSalesAmount => 'Ventas en efectivo';

  @override
  String get cashExpensesAmount => 'Gastos desde caja';

  @override
  String get cashExpectedAmount => 'Efectivo esperado';

  @override
  String get cashPhysicalAmount => 'Conteo físico';

  @override
  String get cashDifferenceAmount => 'Diferencia';

  @override
  String get cashStatusOpen => 'Caja abierta';

  @override
  String get cashStatusClosed => 'Caja cerrada';

  @override
  String get openAction => 'Abrir';

  @override
  String get closeAction => 'Cerrar';

  @override
  String get posCashRegisterRequiredTitle => 'Caja requerida';

  @override
  String get posCashRegisterRequiredMessage =>
      'Abrí tu caja para ingresar al POS y registrar ventas.';

  @override
  String get posStaleCashRegisterRequiredTitle => 'Caja anterior abierta';

  @override
  String posStaleCashRegisterRequiredMessage(String date) {
    return 'La caja del $date quedo abierta. Debes cerrarla antes de abrir la caja de hoy.';
  }

  @override
  String get posOpenCashRegisterAction => 'Abrir caja';

  @override
  String get posCloseCashRegisterAction => 'Cerrar caja';

  @override
  String get posViewTransactionsAction => 'Ver Transacciones';

  @override
  String get posNoTransactionsMessage =>
      'No hay transacciones cobradas en esta caja.';

  @override
  String get posTransactionsTotalLabel => 'Total cobrado';

  @override
  String get posCloseCashPendingCart =>
      'No se puede cerrar caja mientras existan mesas con productos pendientes.';

  @override
  String get posExitAction => 'Salir';

  @override
  String get tableOccupiedLabel => 'Ocupada';

  @override
  String get renameTableTitle => 'Renombrar mesa';

  @override
  String get tableDisplayNameField => 'Nombre visible en POS';

  @override
  String get cartTitle => 'Cuenta';

  @override
  String get cartEmptyMessage =>
      'Selecciona productos para agregarlos a la cuenta.';

  @override
  String get checkoutAction => 'Cobrar';

  @override
  String get clearCartAction => 'Limpiar';

  @override
  String get clearCartConfirmTitle => 'Limpiar pedido';

  @override
  String get clearCartConfirmMessage =>
      'Se quitaran todos los productos de la mesa seleccionada. Esta accion no se puede deshacer.';

  @override
  String get removeCartLineConfirmTitle => 'Quitar producto';

  @override
  String removeCartLineConfirmMessage(String name) {
    return 'Se quitara \"$name\" del pedido. Esta accion no se puede deshacer.';
  }

  @override
  String get removeSplitAccountConfirmTitle => 'Quitar cuenta';

  @override
  String removeSplitAccountConfirmMessage(String name) {
    return 'Se quitara la cuenta \"$name\" y sus productos regresaran a la orden original.';
  }

  @override
  String get paymentReferenceField => 'Referencia de pago';

  @override
  String get paymentGroupField => 'Grupo de pago';

  @override
  String get paymentParentField => 'Ubicación';

  @override
  String get paymentRootOption => 'Nivel principal';

  @override
  String get paymentFinalOptionField => 'Opción cobrable en POS';

  @override
  String get paymentNavigationNode => 'Grupo de navegación';

  @override
  String get removePaymentLevelTitle => 'Quitar nivel de pago';

  @override
  String removePaymentLevelMessage(String name) {
    return 'Se eliminara el nivel \"$name\". Sus bancos, cuentas u opciones directas quedaran dentro del nivel anterior.';
  }

  @override
  String get removePaymentLevelWithChildrenMessage =>
      'Esta accion no elimina un metodo de pago principal.';

  @override
  String get removePaymentLevelConfirm => 'Quitar nivel';

  @override
  String get currencyCodeField => 'Moneda';

  @override
  String get exchangeRateField => 'Tasa';

  @override
  String get exchangeRateMonthLabel => 'Mes';

  @override
  String get exchangeRateMonthlyField => 'Tasa para todo el mes';

  @override
  String get exchangeRateApplyMonthAction => 'Aplicar al mes';

  @override
  String get exchangeRateNotConfigured => 'No configurada';

  @override
  String exchangeRateMissingMessage(String currency) {
    return 'No existe tasa de cambio para $currency en el dia actual.';
  }

  @override
  String get moreOptionsAction => 'Más opciones';

  @override
  String get moreOptionsEmptyMessage =>
      'Aquí se agregarán opciones secundarias del POS.';

  @override
  String get posRegisterExpenseAction => 'Registrar Gasto';

  @override
  String paymentAmountTitle(String method) {
    return 'Monto $method';
  }

  @override
  String get paymentAmountInsufficient =>
      'El monto recibido no cubre el total.';

  @override
  String paymentChangeMessage(String amount) {
    return 'Vuelto: $amount';
  }

  @override
  String get posAmountReceivedField => 'Recibido';

  @override
  String get posChangeDueLabel => 'Cambio';

  @override
  String get posDescriptionColumn => 'Descripcion';

  @override
  String get posServedColumn => 'Servido';

  @override
  String get posQuantityColumn => 'Cantidad';

  @override
  String get posPriceColumn => 'Precio';

  @override
  String get posAmountColumn => 'Monto';

  @override
  String get posRemoveColumn => 'Remover';

  @override
  String get posMarkServedTooltip => 'Marcar como servido';

  @override
  String get posMarkPendingTooltip => 'Marcar como pendiente';

  @override
  String get posHideProductsAction => 'Ocultar Productos';

  @override
  String get posShowProductsAction => 'Mostrar Productos';

  @override
  String get posHideProductsCompactAction => 'Ocultar';

  @override
  String get posShowProductsCompactAction => 'Mostrar';

  @override
  String posTodayExchangeRateLabel(String rate) {
    return 'Tasa de cambio del dia: $rate';
  }

  @override
  String get paymentMethodField => 'Método de pago';

  @override
  String posTodayExchangeRateCompactLabel(String rate) {
    return 'Tasa: $rate';
  }

  @override
  String get tableField => 'Mesa';

  @override
  String get tableStatusAvailable => 'Disponible';

  @override
  String get tableStatusOccupied => 'Ocupada';

  @override
  String get tableStatusDisabled => 'Inactiva';

  @override
  String get noTableOption => 'Sin mesa';

  @override
  String get splitAccountsAction => 'Separar cuentas';

  @override
  String get splitAccountsTitle => 'Separar cuentas';

  @override
  String get accountCountField => 'Cantidad de cuentas';

  @override
  String get accountNameField => 'Nombre de cuenta';

  @override
  String get assignItemsTitle => 'Asignar productos';

  @override
  String get selectAccountHint => 'Selecciona una cuenta';

  @override
  String get pendingItemsTitle => 'Productos pendientes';

  @override
  String get assignedItemsTitle => 'Productos asignados';

  @override
  String get splitAccountsHelp =>
      'Selecciona una cuenta y toca los productos que pertenecen a esa factura.';

  @override
  String get splitAccountsPendingError =>
      'Asigna todos los productos y deja al menos un producto en cada cuenta.';

  @override
  String get splitAccountsMinimumItemsError =>
      'Solo se puede separar una cuenta cuando la mesa tiene más de un producto.';

  @override
  String get splitAddAccountAction => 'Agregar cuenta';

  @override
  String get splitOriginalOrderTitle => 'Orden original';

  @override
  String get splitSelectedItemHint => 'Producto seleccionado';

  @override
  String get splitTapAccountHint => 'Toca una cuenta para moverlo.';

  @override
  String get splitRemoveAccountAction => 'Eliminar cuenta';

  @override
  String get splitReturnItemAction => 'Regresar a la orden';

  @override
  String get splitAccountTotalLabel => 'Total';

  @override
  String get confirmSplitAction => 'Confirmar separación';

  @override
  String get splitAccountsConfirmedMessage =>
      'Cuentas separadas listas para facturar.';

  @override
  String get splitAccountPaymentsTitle => 'Pago por cuenta';

  @override
  String get checkoutSuccessTitle => 'Venta registrada';

  @override
  String get checkoutSuccessMessage => 'La venta se guardó localmente.';

  @override
  String get businessSettingsTitle => 'Datos del negocio';

  @override
  String get businessNameField => 'Nombre comercial';

  @override
  String get legalNameField => 'Razón social';

  @override
  String get taxNumberField => 'RUC';

  @override
  String get phoneField => 'Teléfono';

  @override
  String get addressField => 'Dirección';

  @override
  String get invoicePrefixField => 'Prefijo de factura';

  @override
  String get initialInvoiceNumberField => 'Número inicial';

  @override
  String get showCompanyInfoOnPdfField => 'Mostrar datos de empresa en PDF';

  @override
  String get settingsSavedMessage => 'Configuración guardada.';

  @override
  String get emptyRolesTitle => 'Sin roles';

  @override
  String get emptyRolesMessage =>
      'Crea roles y asigna permisos para controlar el acceso.';

  @override
  String get emptyUsersTitle => 'Sin usuarios';

  @override
  String get emptyUsersMessage => 'Crea usuarios locales y asígnales un rol.';

  @override
  String get emptyAuditTitle => 'Sin eventos';

  @override
  String get emptyAuditMessage =>
      'No hay acciones auditadas para la fecha seleccionada.';

  @override
  String get auditActionCategorySaved => 'CategorÃ­a guardada';

  @override
  String get auditActionProductSaved => 'Producto guardado';

  @override
  String get auditActionPaymentMethodSaved => 'MÃ©todo de pago guardado';

  @override
  String get auditActionTableSaved => 'Mesa guardada';

  @override
  String get auditActionSaleVoided => 'Venta anulada';

  @override
  String get auditActionCashOpened => 'Caja abierta';

  @override
  String get auditActionCashClosed => 'Caja cerrada';

  @override
  String get auditActionExpenseCategorySaved => 'CategorÃ­a de gasto guardada';

  @override
  String get auditActionExpenseCategoryDeleted =>
      'Categoría de gasto eliminada';

  @override
  String get auditActionExpenseSaved => 'Gasto registrado';

  @override
  String get auditActionSettingsSaved => 'ConfiguraciÃ³n guardada';

  @override
  String get auditActionRoleSaved => 'Rol guardado';

  @override
  String get auditActionUserSaved => 'Usuario guardado';

  @override
  String get auditDetailReason => 'Motivo';

  @override
  String get auditDetailStatus => 'Estado';

  @override
  String get auditDetailOptionGroups => 'Grupos de opciones';

  @override
  String get auditDetailPermissions => 'Permisos';

  @override
  String get emptySyncTitle => 'Sin pendientes';

  @override
  String get emptySyncMessage =>
      'No hay operaciones locales pendientes de sincronizar.';

  @override
  String get syncNowAction => 'Sincronizar ahora';

  @override
  String get syncOperationCreate => 'Registro nuevo';

  @override
  String get syncOperationUpdate => 'Actualización';

  @override
  String get syncOperationDelete => 'Eliminación';

  @override
  String get syncStatusPending => 'Pendiente';

  @override
  String get syncStatusSyncing => 'Sincronizando';

  @override
  String get syncStatusSynced => 'Sincronizado';

  @override
  String get syncStatusError => 'Con error';

  @override
  String get syncLastError => 'Último error';

  @override
  String syncRetryCount(int count) {
    return 'Reintentos: $count';
  }

  @override
  String syncSummary(int processed, int succeeded, int failed) {
    return 'Procesadas: $processed | Correctas: $succeeded | Fallidas: $failed';
  }

  @override
  String get createRoleTitle => 'Nuevo rol';

  @override
  String get editRoleTitle => 'Editar rol';

  @override
  String get roleDescriptionField => 'Descripción';

  @override
  String get systemRoleField => 'Rol del sistema';

  @override
  String get permissionsSection => 'Permisos';

  @override
  String get createUserTitle => 'Nuevo usuario';

  @override
  String get editUserTitle => 'Editar usuario';

  @override
  String get displayNameField => 'Nombre visible';

  @override
  String get emailField => 'Correo';

  @override
  String get pinField => 'PIN';

  @override
  String get pinOptionalField => 'PIN nuevo (opcional)';

  @override
  String get posUserField => 'Usuario POS';

  @override
  String get posUserHelp =>
      'Al iniciar sesion entra directo al flujo operativo del POS.';

  @override
  String get loginTitle => 'Iniciar sesion';

  @override
  String get loginMessage =>
      'Ingresa con tu correo y PIN para operar SmooControl.';

  @override
  String get loginAction => 'Entrar';

  @override
  String get initialAdminTitle => 'Crear administrador inicial';

  @override
  String get initialAdminMessage =>
      'No hay usuarios con PIN. Crea el primer administrador para activar el acceso.';

  @override
  String get createInitialAdminAction => 'Crear administrador';

  @override
  String get accessDeniedTitle => 'Acceso restringido';

  @override
  String get accessDeniedMessage =>
      'Tu usuario no tiene permisos para abrir esta pantalla.';

  @override
  String get roleField => 'Rol';

  @override
  String get noRoleAvailableMessage => 'Primero crea un rol activo.';
}
