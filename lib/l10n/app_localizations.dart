import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'SmooControl'**
  String get appTitle;

  /// No description provided for @dashboardTitle.
  ///
  /// In es, this message translates to:
  /// **'Panel operativo'**
  String get dashboardTitle;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Base inicial lista para ventas, caja, gastos y sincronización.'**
  String get dashboardSubtitle;

  /// No description provided for @primaryAction.
  ///
  /// In es, this message translates to:
  /// **'Abrir POS'**
  String get primaryAction;

  /// No description provided for @secondaryAction.
  ///
  /// In es, this message translates to:
  /// **'Ver reportes'**
  String get secondaryAction;

  /// No description provided for @signOutAction.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesion'**
  String get signOutAction;

  /// No description provided for @trackingStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado del proyecto'**
  String get trackingStatus;

  /// No description provided for @trackingStatusValue.
  ///
  /// In es, this message translates to:
  /// **'Base en preparación'**
  String get trackingStatusValue;

  /// No description provided for @offlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Offline-first'**
  String get offlineFirst;

  /// No description provided for @offlineFirstValue.
  ///
  /// In es, this message translates to:
  /// **'La app guardará ventas y gastos localmente antes de sincronizar.'**
  String get offlineFirstValue;

  /// No description provided for @responsiveReady.
  ///
  /// In es, this message translates to:
  /// **'Responsivo'**
  String get responsiveReady;

  /// No description provided for @responsiveReadyValue.
  ///
  /// In es, this message translates to:
  /// **'Diseñado para móvil, tablet y web desde el inicio.'**
  String get responsiveReadyValue;

  /// No description provided for @moduleCatalog.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get moduleCatalog;

  /// No description provided for @moduleProducts.
  ///
  /// In es, this message translates to:
  /// **'Productos'**
  String get moduleProducts;

  /// No description provided for @moduleModifiers.
  ///
  /// In es, this message translates to:
  /// **'Modificadores POS'**
  String get moduleModifiers;

  /// No description provided for @modulePaymentMethods.
  ///
  /// In es, this message translates to:
  /// **'Métodos de pago'**
  String get modulePaymentMethods;

  /// No description provided for @moduleTables.
  ///
  /// In es, this message translates to:
  /// **'Mesas'**
  String get moduleTables;

  /// No description provided for @moduleSales.
  ///
  /// In es, this message translates to:
  /// **'Ventas'**
  String get moduleSales;

  /// No description provided for @moduleCashRegister.
  ///
  /// In es, this message translates to:
  /// **'Caja diaria'**
  String get moduleCashRegister;

  /// No description provided for @cashRegisterAdminTitle.
  ///
  /// In es, this message translates to:
  /// **'Transacciones de caja'**
  String get cashRegisterAdminTitle;

  /// No description provided for @cashRegisterAdminEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay cajas en este rango.'**
  String get cashRegisterAdminEmpty;

  /// No description provided for @cashRegisterAdminEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar caja'**
  String get cashRegisterAdminEdit;

  /// No description provided for @cashRegisterAdminDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar caja'**
  String get cashRegisterAdminDelete;

  /// No description provided for @cashRegisterAdminDeleted.
  ///
  /// In es, this message translates to:
  /// **'Caja eliminada.'**
  String get cashRegisterAdminDeleted;

  /// No description provided for @cashRegisterAdminSaved.
  ///
  /// In es, this message translates to:
  /// **'Caja actualizada.'**
  String get cashRegisterAdminSaved;

  /// No description provided for @cashRegisterAdminDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'Esta accion elimina la caja en Supabase. Si tiene ventas o gastos vinculados, la operacion sera rechazada.'**
  String get cashRegisterAdminDeleteConfirm;

  /// No description provided for @cashRegisterAdminOpened.
  ///
  /// In es, this message translates to:
  /// **'Aperturada'**
  String get cashRegisterAdminOpened;

  /// No description provided for @cashRegisterAdminClosed.
  ///
  /// In es, this message translates to:
  /// **'Cerrada'**
  String get cashRegisterAdminClosed;

  /// No description provided for @moduleExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get moduleExpenses;

  /// No description provided for @moduleExchangeRates.
  ///
  /// In es, this message translates to:
  /// **'Tasas de cambio'**
  String get moduleExchangeRates;

  /// No description provided for @moduleSettings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get moduleSettings;

  /// No description provided for @moduleRoles.
  ///
  /// In es, this message translates to:
  /// **'Roles'**
  String get moduleRoles;

  /// No description provided for @moduleUsers.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get moduleUsers;

  /// No description provided for @moduleAudit.
  ///
  /// In es, this message translates to:
  /// **'Auditoría'**
  String get moduleAudit;

  /// No description provided for @moduleSync.
  ///
  /// In es, this message translates to:
  /// **'Sincronización'**
  String get moduleSync;

  /// No description provided for @moduleComingSoon.
  ///
  /// In es, this message translates to:
  /// **'Módulo en preparación'**
  String get moduleComingSoon;

  /// No description provided for @emptyCatalogTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin categorías'**
  String get emptyCatalogTitle;

  /// No description provided for @emptyCatalogMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea categorías y subcategorías para ordenar el POS.'**
  String get emptyCatalogMessage;

  /// No description provided for @emptyProductsTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin productos'**
  String get emptyProductsTitle;

  /// No description provided for @emptyProductsMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea productos para venderlos desde el POS.'**
  String get emptyProductsMessage;

  /// No description provided for @emptyModifiersTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin modificadores'**
  String get emptyModifiersTitle;

  /// No description provided for @emptyModifiersMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea grupos como Bastimento o Guarnicion y agrega las opciones disponibles.'**
  String get emptyModifiersMessage;

  /// No description provided for @emptyPaymentMethodsTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin métodos de pago'**
  String get emptyPaymentMethodsTitle;

  /// No description provided for @emptyPaymentMethodsMessage.
  ///
  /// In es, this message translates to:
  /// **'Configura efectivo, tarjeta, transferencia u otros métodos.'**
  String get emptyPaymentMethodsMessage;

  /// No description provided for @emptyTablesTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin mesas'**
  String get emptyTablesTitle;

  /// No description provided for @emptyTablesMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea las mesas que se usarán en el servicio.'**
  String get emptyTablesMessage;

  /// No description provided for @emptySalesTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin ventas'**
  String get emptySalesTitle;

  /// No description provided for @emptySalesMessage.
  ///
  /// In es, this message translates to:
  /// **'Las ventas registradas aparecerán aquí.'**
  String get emptySalesMessage;

  /// No description provided for @salesDateLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get salesDateLabel;

  /// No description provided for @emptyExpensesTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin categorías de gastos'**
  String get emptyExpensesTitle;

  /// No description provided for @emptyExpensesMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea categorías para controlar salidas operativas.'**
  String get emptyExpensesMessage;

  /// No description provided for @posReadyTitle.
  ///
  /// In es, this message translates to:
  /// **'POS en preparación'**
  String get posReadyTitle;

  /// No description provided for @posReadyMessage.
  ///
  /// In es, this message translates to:
  /// **'La pantalla de facturación usará categorías, productos, mesas y cuentas separadas.'**
  String get posReadyMessage;

  /// No description provided for @reportsReadyTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportes en preparación'**
  String get reportsReadyTitle;

  /// No description provided for @reportsReadyMessage.
  ///
  /// In es, this message translates to:
  /// **'Aquí se mostrarán ventas, ganancias, gastos, caja y anulaciones.'**
  String get reportsReadyMessage;

  /// No description provided for @reportPeriodToday.
  ///
  /// In es, this message translates to:
  /// **'Día'**
  String get reportPeriodToday;

  /// No description provided for @reportPeriodWeek.
  ///
  /// In es, this message translates to:
  /// **'Semana'**
  String get reportPeriodWeek;

  /// No description provided for @reportPeriodMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get reportPeriodMonth;

  /// No description provided for @reportPeriodYear.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get reportPeriodYear;

  /// No description provided for @reportPeriodCustom.
  ///
  /// In es, this message translates to:
  /// **'Rango'**
  String get reportPeriodCustom;

  /// No description provided for @reportSelectDate.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar fecha'**
  String get reportSelectDate;

  /// No description provided for @reportSelectRange.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar rango'**
  String get reportSelectRange;

  /// No description provided for @reportRangeLabel.
  ///
  /// In es, this message translates to:
  /// **'Rango'**
  String get reportRangeLabel;

  /// No description provided for @reportGrossSales.
  ///
  /// In es, this message translates to:
  /// **'Ventas'**
  String get reportGrossSales;

  /// No description provided for @reportGrossProfit.
  ///
  /// In es, this message translates to:
  /// **'Ganancia bruta'**
  String get reportGrossProfit;

  /// No description provided for @reportExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get reportExpenses;

  /// No description provided for @reportExpensesDetail.
  ///
  /// In es, this message translates to:
  /// **'Detalle de gastos'**
  String get reportExpensesDetail;

  /// No description provided for @reportNoExpenses.
  ///
  /// In es, this message translates to:
  /// **'Sin gastos registrados en este periodo.'**
  String get reportNoExpenses;

  /// No description provided for @expenseCategoryFilter.
  ///
  /// In es, this message translates to:
  /// **'Filtrar por categoria'**
  String get expenseCategoryFilter;

  /// No description provided for @allCategoriesOption.
  ///
  /// In es, this message translates to:
  /// **'Todas las categorias'**
  String get allCategoriesOption;

  /// No description provided for @reportNetProfit.
  ///
  /// In es, this message translates to:
  /// **'Ganancia real'**
  String get reportNetProfit;

  /// No description provided for @reportAverageTicket.
  ///
  /// In es, this message translates to:
  /// **'Ticket promedio'**
  String get reportAverageTicket;

  /// No description provided for @reportSalesCount.
  ///
  /// In es, this message translates to:
  /// **'Ventas registradas'**
  String get reportSalesCount;

  /// No description provided for @reportVoidsCount.
  ///
  /// In es, this message translates to:
  /// **'Anulaciones'**
  String get reportVoidsCount;

  /// No description provided for @reportCashSessions.
  ///
  /// In es, this message translates to:
  /// **'Cajas registradas'**
  String get reportCashSessions;

  /// No description provided for @reportVoidsDetail.
  ///
  /// In es, this message translates to:
  /// **'Detalle de anulaciones'**
  String get reportVoidsDetail;

  /// No description provided for @reportNoVoids.
  ///
  /// In es, this message translates to:
  /// **'Sin anulaciones en este periodo.'**
  String get reportNoVoids;

  /// No description provided for @reportVoidBy.
  ///
  /// In es, this message translates to:
  /// **'Anulada por'**
  String get reportVoidBy;

  /// No description provided for @localUserLabel.
  ///
  /// In es, this message translates to:
  /// **'Usuario local'**
  String get localUserLabel;

  /// No description provided for @reportTopProducts.
  ///
  /// In es, this message translates to:
  /// **'Productos más vendidos'**
  String get reportTopProducts;

  /// No description provided for @reportLowestProducts.
  ///
  /// In es, this message translates to:
  /// **'Productos menos vendidos'**
  String get reportLowestProducts;

  /// No description provided for @reportNoProducts.
  ///
  /// In es, this message translates to:
  /// **'Sin productos vendidos en este periodo.'**
  String get reportNoProducts;

  /// No description provided for @reportUnitsSold.
  ///
  /// In es, this message translates to:
  /// **'unidades'**
  String get reportUnitsSold;

  /// No description provided for @activeStatus.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get activeStatus;

  /// No description provided for @inactiveStatus.
  ///
  /// In es, this message translates to:
  /// **'Inactivo'**
  String get inactiveStatus;

  /// No description provided for @availableInPosField.
  ///
  /// In es, this message translates to:
  /// **'Disponible en POS'**
  String get availableInPosField;

  /// No description provided for @availableInPosStatus.
  ///
  /// In es, this message translates to:
  /// **'Disponible en POS'**
  String get availableInPosStatus;

  /// No description provided for @unavailableInPosStatus.
  ///
  /// In es, this message translates to:
  /// **'No disponible en POS'**
  String get unavailableInPosStatus;

  /// No description provided for @productOptionGroupsField.
  ///
  /// In es, this message translates to:
  /// **'Opciones para POS'**
  String get productOptionGroupsField;

  /// No description provided for @productOptionGroupsEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Agrega grupos solo si el producto debe pedir acompanamientos, bases u otras elecciones.'**
  String get productOptionGroupsEmptyMessage;

  /// No description provided for @productOptionGroupsFormatError.
  ///
  /// In es, this message translates to:
  /// **'Completa el nombre del grupo y al menos una opcion.'**
  String get productOptionGroupsFormatError;

  /// No description provided for @productModifierGroupsField.
  ///
  /// In es, this message translates to:
  /// **'Grupos modificadores'**
  String get productModifierGroupsField;

  /// No description provided for @productModifierGroupsEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea grupos en Modificadores POS y luego asignelos al producto.'**
  String get productModifierGroupsEmptyMessage;

  /// No description provided for @productHasOptionsStatus.
  ///
  /// In es, this message translates to:
  /// **'Pide opciones en POS'**
  String get productHasOptionsStatus;

  /// No description provided for @selectProductOptionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar opciones'**
  String get selectProductOptionsTitle;

  /// No description provided for @addOptionGroupAction.
  ///
  /// In es, this message translates to:
  /// **'Agregar grupo'**
  String get addOptionGroupAction;

  /// No description provided for @optionGroupNameField.
  ///
  /// In es, this message translates to:
  /// **'Nombre del grupo'**
  String get optionGroupNameField;

  /// No description provided for @optionGroupRequiredField.
  ///
  /// In es, this message translates to:
  /// **'Requerido en POS'**
  String get optionGroupRequiredField;

  /// No description provided for @productOptionField.
  ///
  /// In es, this message translates to:
  /// **'Opcion'**
  String get productOptionField;

  /// No description provided for @addOptionAction.
  ///
  /// In es, this message translates to:
  /// **'Agregar opcion'**
  String get addOptionAction;

  /// No description provided for @skipOptionalOptionAction.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get skipOptionalOptionAction;

  /// No description provided for @removeAction.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get removeAction;

  /// No description provided for @deleteAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteAction;

  /// No description provided for @nextAction.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get nextAction;

  /// No description provided for @previousAction.
  ///
  /// In es, this message translates to:
  /// **'Anterior'**
  String get previousAction;

  /// No description provided for @addToCartAction.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get addToCartAction;

  /// No description provided for @cashAffectsRegister.
  ///
  /// In es, this message translates to:
  /// **'Afecta efectivo'**
  String get cashAffectsRegister;

  /// No description provided for @requiresReference.
  ///
  /// In es, this message translates to:
  /// **'Requiere referencia'**
  String get requiresReference;

  /// No description provided for @saleStatusCompleted.
  ///
  /// In es, this message translates to:
  /// **'Completada'**
  String get saleStatusCompleted;

  /// No description provided for @saleStatusVoided.
  ///
  /// In es, this message translates to:
  /// **'Anulada'**
  String get saleStatusVoided;

  /// No description provided for @voidSaleAction.
  ///
  /// In es, this message translates to:
  /// **'Anular'**
  String get voidSaleAction;

  /// No description provided for @voidSaleTitle.
  ///
  /// In es, this message translates to:
  /// **'Anular venta'**
  String get voidSaleTitle;

  /// No description provided for @voidReasonField.
  ///
  /// In es, this message translates to:
  /// **'Motivo de anulación'**
  String get voidReasonField;

  /// No description provided for @saleVoidedMessage.
  ///
  /// In es, this message translates to:
  /// **'Venta anulada.'**
  String get saleVoidedMessage;

  /// No description provided for @generatePdfAction.
  ///
  /// In es, this message translates to:
  /// **'Generar PDF'**
  String get generatePdfAction;

  /// No description provided for @previewPdfAction.
  ///
  /// In es, this message translates to:
  /// **'Ver comprobante'**
  String get previewPdfAction;

  /// No description provided for @invoicePreviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Vista previa del comprobante'**
  String get invoicePreviewTitle;

  /// No description provided for @pdfGenerationError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo generar el PDF.'**
  String get pdfGenerationError;

  /// No description provided for @createAction.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get createAction;

  /// No description provided for @editAction.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get editAction;

  /// No description provided for @confirmAction.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirmAction;

  /// No description provided for @cancelAction.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelAction;

  /// No description provided for @okAction.
  ///
  /// In es, this message translates to:
  /// **'OK'**
  String get okAction;

  /// No description provided for @saveAction.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get saveAction;

  /// No description provided for @reloadAction.
  ///
  /// In es, this message translates to:
  /// **'Recargar'**
  String get reloadAction;

  /// No description provided for @backAction.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get backAction;

  /// No description provided for @searchField.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get searchField;

  /// No description provided for @emptySearchTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get emptySearchTitle;

  /// No description provided for @emptySearchMessage.
  ///
  /// In es, this message translates to:
  /// **'No hay registros que coincidan con la busqueda.'**
  String get emptySearchMessage;

  /// No description provided for @nameField.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get nameField;

  /// No description provided for @categoryTypeField.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get categoryTypeField;

  /// No description provided for @categoryTypeCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get categoryTypeCategory;

  /// No description provided for @categoryTypeSubcategory.
  ///
  /// In es, this message translates to:
  /// **'Subcategoría'**
  String get categoryTypeSubcategory;

  /// No description provided for @catalogParentField.
  ///
  /// In es, this message translates to:
  /// **'Ubicar dentro de'**
  String get catalogParentField;

  /// No description provided for @rootCategoryOption.
  ///
  /// In es, this message translates to:
  /// **'Categoría principal'**
  String get rootCategoryOption;

  /// No description provided for @categoryInsideOf.
  ///
  /// In es, this message translates to:
  /// **'Dentro de'**
  String get categoryInsideOf;

  /// No description provided for @expandGroupAction.
  ///
  /// In es, this message translates to:
  /// **'Expandir grupo'**
  String get expandGroupAction;

  /// No description provided for @collapseGroupAction.
  ///
  /// In es, this message translates to:
  /// **'Contraer grupo'**
  String get collapseGroupAction;

  /// No description provided for @expandedStatus.
  ///
  /// In es, this message translates to:
  /// **'Expandido'**
  String get expandedStatus;

  /// No description provided for @collapsedStatus.
  ///
  /// In es, this message translates to:
  /// **'Contraído'**
  String get collapsedStatus;

  /// No description provided for @parentCategoryField.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get parentCategoryField;

  /// No description provided for @priceInCentsField.
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get priceInCentsField;

  /// No description provided for @costInCentsField.
  ///
  /// In es, this message translates to:
  /// **'Costo'**
  String get costInCentsField;

  /// No description provided for @createCategoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva categoría'**
  String get createCategoryTitle;

  /// No description provided for @editCategoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar categoría'**
  String get editCategoryTitle;

  /// No description provided for @removeCategoryLevelTitle.
  ///
  /// In es, this message translates to:
  /// **'Quitar nivel'**
  String get removeCategoryLevelTitle;

  /// No description provided for @removeCategoryLevelMessage.
  ///
  /// In es, this message translates to:
  /// **'Se eliminara el nivel \"{name}\". Sus productos y subniveles directos quedaran dentro del nivel anterior.'**
  String removeCategoryLevelMessage(String name);

  /// No description provided for @removeCategoryLevelWithChildrenMessage.
  ///
  /// In es, this message translates to:
  /// **'Esta accion no elimina la categoria principal.'**
  String get removeCategoryLevelWithChildrenMessage;

  /// No description provided for @removeCategoryLevelConfirm.
  ///
  /// In es, this message translates to:
  /// **'Quitar nivel'**
  String get removeCategoryLevelConfirm;

  /// No description provided for @createProductTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo producto'**
  String get createProductTitle;

  /// No description provided for @editProductTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar producto'**
  String get editProductTitle;

  /// No description provided for @createModifierGroupTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo grupo modificador'**
  String get createModifierGroupTitle;

  /// No description provided for @editModifierGroupTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar grupo modificador'**
  String get editModifierGroupTitle;

  /// No description provided for @createModifierOptionTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva opcion modificadora'**
  String get createModifierOptionTitle;

  /// No description provided for @editModifierOptionTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar opcion modificadora'**
  String get editModifierOptionTitle;

  /// No description provided for @addModifierOptionAction.
  ///
  /// In es, this message translates to:
  /// **'Agregar opcion'**
  String get addModifierOptionAction;

  /// No description provided for @deactivateAction.
  ///
  /// In es, this message translates to:
  /// **'Inactivar'**
  String get deactivateAction;

  /// No description provided for @deactivateCatalogItemTitle.
  ///
  /// In es, this message translates to:
  /// **'Inactivar registro'**
  String get deactivateCatalogItemTitle;

  /// No description provided for @deactivateCatalogItemMessage.
  ///
  /// In es, this message translates to:
  /// **'Se inactivara \"{name}\". El historico se conserva y no se borra fisicamente.'**
  String deactivateCatalogItemMessage(String name);

  /// No description provided for @deactivateModifierGroupTitle.
  ///
  /// In es, this message translates to:
  /// **'Inactivar grupo modificador'**
  String get deactivateModifierGroupTitle;

  /// No description provided for @deactivateModifierGroupMessage.
  ///
  /// In es, this message translates to:
  /// **'Se inactivara el grupo \"{name}\" y dejara de solicitarse en el POS. Sus opciones se conservan para historico.'**
  String deactivateModifierGroupMessage(String name);

  /// No description provided for @deactivateModifierOptionTitle.
  ///
  /// In es, this message translates to:
  /// **'Inactivar opcion modificadora'**
  String get deactivateModifierOptionTitle;

  /// No description provided for @deactivateModifierOptionMessage.
  ///
  /// In es, this message translates to:
  /// **'Se inactivara la opcion \"{name}\" y dejara de aparecer en el POS.'**
  String deactivateModifierOptionMessage(String name);

  /// No description provided for @modifierGroupNoOptions.
  ///
  /// In es, this message translates to:
  /// **'Sin opciones'**
  String get modifierGroupNoOptions;

  /// No description provided for @modifierGroupOneOption.
  ///
  /// In es, this message translates to:
  /// **'1 opcion'**
  String get modifierGroupOneOption;

  /// No description provided for @modifierGroupManyOptions.
  ///
  /// In es, this message translates to:
  /// **'{count} opciones'**
  String modifierGroupManyOptions(int count);

  /// No description provided for @createPaymentMethodTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo método de pago'**
  String get createPaymentMethodTitle;

  /// No description provided for @editPaymentMethodTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar método de pago'**
  String get editPaymentMethodTitle;

  /// No description provided for @createTableTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva mesa'**
  String get createTableTitle;

  /// No description provided for @editTableTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar mesa'**
  String get editTableTitle;

  /// No description provided for @fieldRequiredError.
  ///
  /// In es, this message translates to:
  /// **'Completa los campos requeridos.'**
  String get fieldRequiredError;

  /// No description provided for @numericFieldError.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un número válido.'**
  String get numericFieldError;

  /// No description provided for @activeField.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get activeField;

  /// No description provided for @optionalFieldHint.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get optionalFieldHint;

  /// No description provided for @optionalField.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get optionalField;

  /// No description provided for @yesLabel.
  ///
  /// In es, this message translates to:
  /// **'Sí'**
  String get yesLabel;

  /// No description provided for @noLabel.
  ///
  /// In es, this message translates to:
  /// **'No'**
  String get noLabel;

  /// No description provided for @createExpenseCategoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva categoría de gasto'**
  String get createExpenseCategoryTitle;

  /// No description provided for @editExpenseCategoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar categoría de gasto'**
  String get editExpenseCategoryTitle;

  /// No description provided for @expenseCategoryCoverageField.
  ///
  /// In es, this message translates to:
  /// **'Restar en cobertura de utilidad'**
  String get expenseCategoryCoverageField;

  /// No description provided for @expenseCategoryCoverageHelp.
  ///
  /// In es, this message translates to:
  /// **'Actívalo solo para gastos operativos reales. No usar en nómina ni compras de inventario.'**
  String get expenseCategoryCoverageHelp;

  /// No description provided for @expenseCategoryCoverageSubcategoryHelp.
  ///
  /// In es, this message translates to:
  /// **'Actívalo solo en subcategorías que deban medirse contra la utilidad bruta.'**
  String get expenseCategoryCoverageSubcategoryHelp;

  /// No description provided for @expenseCategoryCoverageIncluded.
  ///
  /// In es, this message translates to:
  /// **'Entra en cobertura'**
  String get expenseCategoryCoverageIncluded;

  /// No description provided for @expenseCategoryCoverageExcluded.
  ///
  /// In es, this message translates to:
  /// **'Fuera de cobertura'**
  String get expenseCategoryCoverageExcluded;

  /// No description provided for @expenseCoverageTypeField.
  ///
  /// In es, this message translates to:
  /// **'Tipo de gasto'**
  String get expenseCoverageTypeField;

  /// No description provided for @expenseCoverageTypeFixed.
  ///
  /// In es, this message translates to:
  /// **'Fijo'**
  String get expenseCoverageTypeFixed;

  /// No description provided for @expenseCoverageTypeVariable.
  ///
  /// In es, this message translates to:
  /// **'Variable'**
  String get expenseCoverageTypeVariable;

  /// No description provided for @expenseCoverageAmountField.
  ///
  /// In es, this message translates to:
  /// **'Monto estimado'**
  String get expenseCoverageAmountField;

  /// No description provided for @expenseCoverageFrequencyField.
  ///
  /// In es, this message translates to:
  /// **'Frecuencia'**
  String get expenseCoverageFrequencyField;

  /// No description provided for @expenseCoverageFrequencyWeekly.
  ///
  /// In es, this message translates to:
  /// **'Semanal'**
  String get expenseCoverageFrequencyWeekly;

  /// No description provided for @expenseCoverageFrequencyBiweekly.
  ///
  /// In es, this message translates to:
  /// **'Quincenal'**
  String get expenseCoverageFrequencyBiweekly;

  /// No description provided for @expenseCoverageFrequencyMonthly.
  ///
  /// In es, this message translates to:
  /// **'Mensual'**
  String get expenseCoverageFrequencyMonthly;

  /// No description provided for @expenseCoverageFrequencyCustom.
  ///
  /// In es, this message translates to:
  /// **'Personalizada'**
  String get expenseCoverageFrequencyCustom;

  /// No description provided for @expenseCoverageDueDaysField.
  ///
  /// In es, this message translates to:
  /// **'Días de pago'**
  String get expenseCoverageDueDaysField;

  /// No description provided for @expenseCoverageNotesField.
  ///
  /// In es, this message translates to:
  /// **'Notas de cobertura'**
  String get expenseCoverageNotesField;

  /// No description provided for @expenseCoverageAmountRequiredError.
  ///
  /// In es, this message translates to:
  /// **'El monto es obligatorio para gastos fijos.'**
  String get expenseCoverageAmountRequiredError;

  /// No description provided for @expenseCoverageAmountInvalidError.
  ///
  /// In es, this message translates to:
  /// **'El monto de cobertura no es válido.'**
  String get expenseCoverageAmountInvalidError;

  /// No description provided for @expenseCoverageDueDaysRequiredError.
  ///
  /// In es, this message translates to:
  /// **'Indica al menos un día de pago.'**
  String get expenseCoverageDueDaysRequiredError;

  /// No description provided for @expenseCoverageDueDaysInvalidError.
  ///
  /// In es, this message translates to:
  /// **'Los días de pago deben estar entre 1 y 31.'**
  String get expenseCoverageDueDaysInvalidError;

  /// No description provided for @inventoryValueReportTitle.
  ///
  /// In es, this message translates to:
  /// **'Valor de inventario'**
  String get inventoryValueReportTitle;

  /// No description provided for @inventoryValueReportSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Costo actual, venta potencial y utilidad estimada del inventario.'**
  String get inventoryValueReportSubtitle;

  /// No description provided for @monthlyOperationalReportTitle.
  ///
  /// In es, this message translates to:
  /// **'Resultado operativo'**
  String get monthlyOperationalReportTitle;

  /// No description provided for @monthlyOperationalReportSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ventas del mes contra gastos, planilla y utilidad disponible.'**
  String get monthlyOperationalReportSubtitle;

  /// No description provided for @monthlyOperationalEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'No hay ventas, gastos ni planilla para el rango seleccionado.'**
  String get monthlyOperationalEmptyMessage;

  /// No description provided for @monthlyOperationalProductCost.
  ///
  /// In es, this message translates to:
  /// **'Costo productos'**
  String get monthlyOperationalProductCost;

  /// No description provided for @monthlyOperationalConsideredExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos operativos'**
  String get monthlyOperationalConsideredExpenses;

  /// No description provided for @monthlyOperationalPayroll.
  ///
  /// In es, this message translates to:
  /// **'Planilla'**
  String get monthlyOperationalPayroll;

  /// No description provided for @monthlyOperationalResult.
  ///
  /// In es, this message translates to:
  /// **'Resultado'**
  String get monthlyOperationalResult;

  /// No description provided for @monthlyOperationalRiskTitle.
  ///
  /// In es, this message translates to:
  /// **'Utilidad insuficiente'**
  String get monthlyOperationalRiskTitle;

  /// No description provided for @monthlyOperationalRiskMessage.
  ///
  /// In es, this message translates to:
  /// **'La utilidad bruta aun no cubre los gastos operativos y la planilla del periodo.'**
  String get monthlyOperationalRiskMessage;

  /// No description provided for @monthlyOperationalHealthyTitle.
  ///
  /// In es, this message translates to:
  /// **'Cobertura saludable'**
  String get monthlyOperationalHealthyTitle;

  /// No description provided for @monthlyOperationalHealthyMessage.
  ///
  /// In es, this message translates to:
  /// **'La utilidad bruta cubre gastos operativos y planilla del periodo.'**
  String get monthlyOperationalHealthyMessage;

  /// No description provided for @monthlyOperationalCoverage.
  ///
  /// In es, this message translates to:
  /// **'Cobertura usada'**
  String get monthlyOperationalCoverage;

  /// No description provided for @monthlyOperationalPayrollPending.
  ///
  /// In es, this message translates to:
  /// **'Planilla pendiente'**
  String get monthlyOperationalPayrollPending;

  /// No description provided for @monthlyOperationalAdvances.
  ///
  /// In es, this message translates to:
  /// **'Adelantos entregados'**
  String get monthlyOperationalAdvances;

  /// No description provided for @monthlyOperationalPendingConsumption.
  ///
  /// In es, this message translates to:
  /// **'Consumos pendientes'**
  String get monthlyOperationalPendingConsumption;

  /// No description provided for @monthlyOperationalExpensesTitle.
  ///
  /// In es, this message translates to:
  /// **'Gastos considerados'**
  String get monthlyOperationalExpensesTitle;

  /// No description provided for @monthlyOperationalExcludedExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos excluidos'**
  String get monthlyOperationalExcludedExpenses;

  /// No description provided for @inventoryValueSearchLabel.
  ///
  /// In es, this message translates to:
  /// **'Buscar producto o categoría'**
  String get inventoryValueSearchLabel;

  /// No description provided for @inventoryOnlyWithStockFilter.
  ///
  /// In es, this message translates to:
  /// **'Solo con stock'**
  String get inventoryOnlyWithStockFilter;

  /// No description provided for @inventoryValueLoadErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar'**
  String get inventoryValueLoadErrorTitle;

  /// No description provided for @inventoryValueEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin datos'**
  String get inventoryValueEmptyTitle;

  /// No description provided for @inventoryValueEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'No hay productos de inventario para el filtro seleccionado.'**
  String get inventoryValueEmptyMessage;

  /// No description provided for @inventoryCostMetric.
  ///
  /// In es, this message translates to:
  /// **'Costo inventario'**
  String get inventoryCostMetric;

  /// No description provided for @inventoryPotentialSalesMetric.
  ///
  /// In es, this message translates to:
  /// **'Venta potencial'**
  String get inventoryPotentialSalesMetric;

  /// No description provided for @inventoryPotentialProfitMetric.
  ///
  /// In es, this message translates to:
  /// **'Utilidad potencial'**
  String get inventoryPotentialProfitMetric;

  /// No description provided for @inventoryMarginMetric.
  ///
  /// In es, this message translates to:
  /// **'Margen'**
  String get inventoryMarginMetric;

  /// No description provided for @inventoryWithStockMetric.
  ///
  /// In es, this message translates to:
  /// **'Con stock'**
  String get inventoryWithStockMetric;

  /// No description provided for @inventoryMissingCostMetric.
  ///
  /// In es, this message translates to:
  /// **'Sin costo'**
  String get inventoryMissingCostMetric;

  /// No description provided for @inventoryMissingPriceMetric.
  ///
  /// In es, this message translates to:
  /// **'Sin precio'**
  String get inventoryMissingPriceMetric;

  /// No description provided for @inventoryLowMarginMetric.
  ///
  /// In es, this message translates to:
  /// **'Margen bajo'**
  String get inventoryLowMarginMetric;

  /// No description provided for @inventoryCategoryValueTitle.
  ///
  /// In es, this message translates to:
  /// **'Valor por categoría'**
  String get inventoryCategoryValueTitle;

  /// No description provided for @inventoryCapitalPercentLabel.
  ///
  /// In es, this message translates to:
  /// **'{percent}% del capital en inventario'**
  String inventoryCapitalPercentLabel(String percent);

  /// No description provided for @inventoryProductColumn.
  ///
  /// In es, this message translates to:
  /// **'Producto'**
  String get inventoryProductColumn;

  /// No description provided for @inventoryCategoryColumn.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get inventoryCategoryColumn;

  /// No description provided for @inventoryStockColumn.
  ///
  /// In es, this message translates to:
  /// **'Stock'**
  String get inventoryStockColumn;

  /// No description provided for @inventoryCostColumn.
  ///
  /// In es, this message translates to:
  /// **'Costo'**
  String get inventoryCostColumn;

  /// No description provided for @inventoryPriceColumn.
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get inventoryPriceColumn;

  /// No description provided for @inventoryCostValueColumn.
  ///
  /// In es, this message translates to:
  /// **'Valor costo'**
  String get inventoryCostValueColumn;

  /// No description provided for @inventoryPotentialSalesColumn.
  ///
  /// In es, this message translates to:
  /// **'Venta potencial'**
  String get inventoryPotentialSalesColumn;

  /// No description provided for @inventoryProfitColumn.
  ///
  /// In es, this message translates to:
  /// **'Utilidad'**
  String get inventoryProfitColumn;

  /// No description provided for @deleteExpenseCategoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar categoría de gasto'**
  String get deleteExpenseCategoryTitle;

  /// No description provided for @deleteExpenseCategoryMessage.
  ///
  /// In es, this message translates to:
  /// **'Se eliminara \"{name}\". Si tiene categorias hijas, quedaran en la raiz.'**
  String deleteExpenseCategoryMessage(String name);

  /// No description provided for @createExpenseTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo gasto'**
  String get createExpenseTitle;

  /// No description provided for @expenseSavedMessage.
  ///
  /// In es, this message translates to:
  /// **'Gasto registrado correctamente.'**
  String get expenseSavedMessage;

  /// No description provided for @expenseCategoriesSection.
  ///
  /// In es, this message translates to:
  /// **'Categorías de gasto'**
  String get expenseCategoriesSection;

  /// No description provided for @todayExpensesSection.
  ///
  /// In es, this message translates to:
  /// **'Gastos de hoy'**
  String get todayExpensesSection;

  /// No description provided for @noExpensesTodayMessage.
  ///
  /// In es, this message translates to:
  /// **'No hay gastos registrados hoy.'**
  String get noExpensesTodayMessage;

  /// No description provided for @unknownExpenseCategory.
  ///
  /// In es, this message translates to:
  /// **'Sin categoría'**
  String get unknownExpenseCategory;

  /// No description provided for @amountInCentsField.
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get amountInCentsField;

  /// No description provided for @descriptionField.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get descriptionField;

  /// No description provided for @openCashRegisterTitle.
  ///
  /// In es, this message translates to:
  /// **'Abrir caja'**
  String get openCashRegisterTitle;

  /// No description provided for @closeCashRegisterTitle.
  ///
  /// In es, this message translates to:
  /// **'Cerrar caja'**
  String get closeCashRegisterTitle;

  /// No description provided for @openingCashField.
  ///
  /// In es, this message translates to:
  /// **'Efectivo inicial'**
  String get openingCashField;

  /// No description provided for @closingCashField.
  ///
  /// In es, this message translates to:
  /// **'Conteo físico'**
  String get closingCashField;

  /// No description provided for @cashOpeningAmount.
  ///
  /// In es, this message translates to:
  /// **'Efectivo inicial'**
  String get cashOpeningAmount;

  /// No description provided for @cashSalesAmount.
  ///
  /// In es, this message translates to:
  /// **'Ventas en efectivo'**
  String get cashSalesAmount;

  /// No description provided for @cashExpensesAmount.
  ///
  /// In es, this message translates to:
  /// **'Gastos desde caja'**
  String get cashExpensesAmount;

  /// No description provided for @cashExpectedAmount.
  ///
  /// In es, this message translates to:
  /// **'Efectivo esperado'**
  String get cashExpectedAmount;

  /// No description provided for @cashPhysicalAmount.
  ///
  /// In es, this message translates to:
  /// **'Conteo físico'**
  String get cashPhysicalAmount;

  /// No description provided for @cashDifferenceAmount.
  ///
  /// In es, this message translates to:
  /// **'Diferencia'**
  String get cashDifferenceAmount;

  /// No description provided for @cashStatusOpen.
  ///
  /// In es, this message translates to:
  /// **'Caja abierta'**
  String get cashStatusOpen;

  /// No description provided for @cashStatusClosed.
  ///
  /// In es, this message translates to:
  /// **'Caja cerrada'**
  String get cashStatusClosed;

  /// No description provided for @openAction.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get openAction;

  /// No description provided for @closeAction.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get closeAction;

  /// No description provided for @posCashRegisterRequiredTitle.
  ///
  /// In es, this message translates to:
  /// **'Caja requerida'**
  String get posCashRegisterRequiredTitle;

  /// No description provided for @posCashRegisterRequiredMessage.
  ///
  /// In es, this message translates to:
  /// **'Abrí tu caja para ingresar al POS y registrar ventas.'**
  String get posCashRegisterRequiredMessage;

  /// No description provided for @posStaleCashRegisterRequiredTitle.
  ///
  /// In es, this message translates to:
  /// **'Caja anterior abierta'**
  String get posStaleCashRegisterRequiredTitle;

  /// No description provided for @posStaleCashRegisterRequiredMessage.
  ///
  /// In es, this message translates to:
  /// **'La caja del {date} quedo abierta. Debes cerrarla antes de abrir la caja de hoy.'**
  String posStaleCashRegisterRequiredMessage(String date);

  /// No description provided for @posOpenCashRegisterAction.
  ///
  /// In es, this message translates to:
  /// **'Abrir caja'**
  String get posOpenCashRegisterAction;

  /// No description provided for @posCloseCashRegisterAction.
  ///
  /// In es, this message translates to:
  /// **'Cerrar caja'**
  String get posCloseCashRegisterAction;

  /// No description provided for @posViewTransactionsAction.
  ///
  /// In es, this message translates to:
  /// **'Ver Transacciones'**
  String get posViewTransactionsAction;

  /// No description provided for @posNoTransactionsMessage.
  ///
  /// In es, this message translates to:
  /// **'No hay transacciones cobradas en esta caja.'**
  String get posNoTransactionsMessage;

  /// No description provided for @posTransactionsTotalLabel.
  ///
  /// In es, this message translates to:
  /// **'Total cobrado'**
  String get posTransactionsTotalLabel;

  /// No description provided for @posCloseCashPendingCart.
  ///
  /// In es, this message translates to:
  /// **'No se puede cerrar caja mientras existan mesas con productos pendientes.'**
  String get posCloseCashPendingCart;

  /// No description provided for @posExitAction.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get posExitAction;

  /// No description provided for @tableOccupiedLabel.
  ///
  /// In es, this message translates to:
  /// **'Ocupada'**
  String get tableOccupiedLabel;

  /// No description provided for @renameTableTitle.
  ///
  /// In es, this message translates to:
  /// **'Renombrar mesa'**
  String get renameTableTitle;

  /// No description provided for @tableDisplayNameField.
  ///
  /// In es, this message translates to:
  /// **'Nombre visible en POS'**
  String get tableDisplayNameField;

  /// No description provided for @cartTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get cartTitle;

  /// No description provided for @cartEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Selecciona productos para agregarlos a la cuenta.'**
  String get cartEmptyMessage;

  /// No description provided for @checkoutAction.
  ///
  /// In es, this message translates to:
  /// **'Cobrar'**
  String get checkoutAction;

  /// No description provided for @clearCartAction.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get clearCartAction;

  /// No description provided for @clearCartConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Limpiar pedido'**
  String get clearCartConfirmTitle;

  /// No description provided for @clearCartConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'Se quitaran todos los productos de la mesa seleccionada. Esta accion no se puede deshacer.'**
  String get clearCartConfirmMessage;

  /// No description provided for @removeCartLineConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Quitar producto'**
  String get removeCartLineConfirmTitle;

  /// No description provided for @removeCartLineConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'Se quitara \"{name}\" del pedido. Esta accion no se puede deshacer.'**
  String removeCartLineConfirmMessage(String name);

  /// No description provided for @removeSplitAccountConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Quitar cuenta'**
  String get removeSplitAccountConfirmTitle;

  /// No description provided for @removeSplitAccountConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'Se quitara la cuenta \"{name}\" y sus productos regresaran a la orden original.'**
  String removeSplitAccountConfirmMessage(String name);

  /// No description provided for @paymentReferenceField.
  ///
  /// In es, this message translates to:
  /// **'Referencia de pago'**
  String get paymentReferenceField;

  /// No description provided for @paymentGroupField.
  ///
  /// In es, this message translates to:
  /// **'Grupo de pago'**
  String get paymentGroupField;

  /// No description provided for @paymentParentField.
  ///
  /// In es, this message translates to:
  /// **'Ubicación'**
  String get paymentParentField;

  /// No description provided for @paymentRootOption.
  ///
  /// In es, this message translates to:
  /// **'Nivel principal'**
  String get paymentRootOption;

  /// No description provided for @paymentFinalOptionField.
  ///
  /// In es, this message translates to:
  /// **'Opción cobrable en POS'**
  String get paymentFinalOptionField;

  /// No description provided for @paymentNavigationNode.
  ///
  /// In es, this message translates to:
  /// **'Grupo de navegación'**
  String get paymentNavigationNode;

  /// No description provided for @removePaymentLevelTitle.
  ///
  /// In es, this message translates to:
  /// **'Quitar nivel de pago'**
  String get removePaymentLevelTitle;

  /// No description provided for @removePaymentLevelMessage.
  ///
  /// In es, this message translates to:
  /// **'Se eliminara el nivel \"{name}\". Sus bancos, cuentas u opciones directas quedaran dentro del nivel anterior.'**
  String removePaymentLevelMessage(String name);

  /// No description provided for @removePaymentLevelWithChildrenMessage.
  ///
  /// In es, this message translates to:
  /// **'Esta accion no elimina un metodo de pago principal.'**
  String get removePaymentLevelWithChildrenMessage;

  /// No description provided for @removePaymentLevelConfirm.
  ///
  /// In es, this message translates to:
  /// **'Quitar nivel'**
  String get removePaymentLevelConfirm;

  /// No description provided for @currencyCodeField.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get currencyCodeField;

  /// No description provided for @exchangeRateField.
  ///
  /// In es, this message translates to:
  /// **'Tasa'**
  String get exchangeRateField;

  /// No description provided for @exchangeRateMonthLabel.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get exchangeRateMonthLabel;

  /// No description provided for @exchangeRateMonthlyField.
  ///
  /// In es, this message translates to:
  /// **'Tasa para todo el mes'**
  String get exchangeRateMonthlyField;

  /// No description provided for @exchangeRateApplyMonthAction.
  ///
  /// In es, this message translates to:
  /// **'Aplicar al mes'**
  String get exchangeRateApplyMonthAction;

  /// No description provided for @exchangeRateNotConfigured.
  ///
  /// In es, this message translates to:
  /// **'No configurada'**
  String get exchangeRateNotConfigured;

  /// No description provided for @exchangeRateMissingMessage.
  ///
  /// In es, this message translates to:
  /// **'No existe tasa de cambio para {currency} en el dia actual.'**
  String exchangeRateMissingMessage(String currency);

  /// No description provided for @moreOptionsAction.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get moreOptionsAction;

  /// No description provided for @moreOptionsEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Aquí se agregarán opciones secundarias del POS.'**
  String get moreOptionsEmptyMessage;

  /// No description provided for @posRegisterExpenseAction.
  ///
  /// In es, this message translates to:
  /// **'Registrar Gasto'**
  String get posRegisterExpenseAction;

  /// No description provided for @paymentAmountTitle.
  ///
  /// In es, this message translates to:
  /// **'Monto {method}'**
  String paymentAmountTitle(String method);

  /// No description provided for @paymentAmountInsufficient.
  ///
  /// In es, this message translates to:
  /// **'El monto recibido no cubre el total.'**
  String get paymentAmountInsufficient;

  /// No description provided for @paymentChangeMessage.
  ///
  /// In es, this message translates to:
  /// **'Vuelto: {amount}'**
  String paymentChangeMessage(String amount);

  /// No description provided for @posAmountReceivedField.
  ///
  /// In es, this message translates to:
  /// **'Recibido'**
  String get posAmountReceivedField;

  /// No description provided for @posChangeDueLabel.
  ///
  /// In es, this message translates to:
  /// **'Cambio'**
  String get posChangeDueLabel;

  /// No description provided for @posDescriptionColumn.
  ///
  /// In es, this message translates to:
  /// **'Descripcion'**
  String get posDescriptionColumn;

  /// No description provided for @posServedColumn.
  ///
  /// In es, this message translates to:
  /// **'Servido'**
  String get posServedColumn;

  /// No description provided for @posQuantityColumn.
  ///
  /// In es, this message translates to:
  /// **'Cantidad'**
  String get posQuantityColumn;

  /// No description provided for @posPriceColumn.
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get posPriceColumn;

  /// No description provided for @posAmountColumn.
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get posAmountColumn;

  /// No description provided for @posRemoveColumn.
  ///
  /// In es, this message translates to:
  /// **'Remover'**
  String get posRemoveColumn;

  /// No description provided for @posMarkServedTooltip.
  ///
  /// In es, this message translates to:
  /// **'Marcar como servido'**
  String get posMarkServedTooltip;

  /// No description provided for @posMarkPendingTooltip.
  ///
  /// In es, this message translates to:
  /// **'Marcar como pendiente'**
  String get posMarkPendingTooltip;

  /// No description provided for @posHideProductsAction.
  ///
  /// In es, this message translates to:
  /// **'Ocultar Productos'**
  String get posHideProductsAction;

  /// No description provided for @posShowProductsAction.
  ///
  /// In es, this message translates to:
  /// **'Mostrar Productos'**
  String get posShowProductsAction;

  /// No description provided for @posHideProductsCompactAction.
  ///
  /// In es, this message translates to:
  /// **'Ocultar'**
  String get posHideProductsCompactAction;

  /// No description provided for @posShowProductsCompactAction.
  ///
  /// In es, this message translates to:
  /// **'Mostrar'**
  String get posShowProductsCompactAction;

  /// No description provided for @posTodayExchangeRateLabel.
  ///
  /// In es, this message translates to:
  /// **'Tasa de cambio del dia: {rate}'**
  String posTodayExchangeRateLabel(String rate);

  /// No description provided for @paymentMethodField.
  ///
  /// In es, this message translates to:
  /// **'Método de pago'**
  String get paymentMethodField;

  /// No description provided for @posTodayExchangeRateCompactLabel.
  ///
  /// In es, this message translates to:
  /// **'Tasa: {rate}'**
  String posTodayExchangeRateCompactLabel(String rate);

  /// No description provided for @tableField.
  ///
  /// In es, this message translates to:
  /// **'Mesa'**
  String get tableField;

  /// No description provided for @tableStatusAvailable.
  ///
  /// In es, this message translates to:
  /// **'Disponible'**
  String get tableStatusAvailable;

  /// No description provided for @tableStatusOccupied.
  ///
  /// In es, this message translates to:
  /// **'Ocupada'**
  String get tableStatusOccupied;

  /// No description provided for @tableStatusDisabled.
  ///
  /// In es, this message translates to:
  /// **'Inactiva'**
  String get tableStatusDisabled;

  /// No description provided for @noTableOption.
  ///
  /// In es, this message translates to:
  /// **'Sin mesa'**
  String get noTableOption;

  /// No description provided for @splitAccountsAction.
  ///
  /// In es, this message translates to:
  /// **'Separar cuentas'**
  String get splitAccountsAction;

  /// No description provided for @splitAccountsTitle.
  ///
  /// In es, this message translates to:
  /// **'Separar cuentas'**
  String get splitAccountsTitle;

  /// No description provided for @accountCountField.
  ///
  /// In es, this message translates to:
  /// **'Cantidad de cuentas'**
  String get accountCountField;

  /// No description provided for @accountNameField.
  ///
  /// In es, this message translates to:
  /// **'Nombre de cuenta'**
  String get accountNameField;

  /// No description provided for @assignItemsTitle.
  ///
  /// In es, this message translates to:
  /// **'Asignar productos'**
  String get assignItemsTitle;

  /// No description provided for @selectAccountHint.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una cuenta'**
  String get selectAccountHint;

  /// No description provided for @pendingItemsTitle.
  ///
  /// In es, this message translates to:
  /// **'Productos pendientes'**
  String get pendingItemsTitle;

  /// No description provided for @assignedItemsTitle.
  ///
  /// In es, this message translates to:
  /// **'Productos asignados'**
  String get assignedItemsTitle;

  /// No description provided for @splitAccountsHelp.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una cuenta y toca los productos que pertenecen a esa factura.'**
  String get splitAccountsHelp;

  /// No description provided for @splitAccountsPendingError.
  ///
  /// In es, this message translates to:
  /// **'Asigna todos los productos y deja al menos un producto en cada cuenta.'**
  String get splitAccountsPendingError;

  /// No description provided for @splitAccountsMinimumItemsError.
  ///
  /// In es, this message translates to:
  /// **'Solo se puede separar una cuenta cuando la mesa tiene más de un producto.'**
  String get splitAccountsMinimumItemsError;

  /// No description provided for @splitAddAccountAction.
  ///
  /// In es, this message translates to:
  /// **'Agregar cuenta'**
  String get splitAddAccountAction;

  /// No description provided for @splitOriginalOrderTitle.
  ///
  /// In es, this message translates to:
  /// **'Orden original'**
  String get splitOriginalOrderTitle;

  /// No description provided for @splitSelectedItemHint.
  ///
  /// In es, this message translates to:
  /// **'Producto seleccionado'**
  String get splitSelectedItemHint;

  /// No description provided for @splitTapAccountHint.
  ///
  /// In es, this message translates to:
  /// **'Toca una cuenta para moverlo.'**
  String get splitTapAccountHint;

  /// No description provided for @splitRemoveAccountAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get splitRemoveAccountAction;

  /// No description provided for @splitReturnItemAction.
  ///
  /// In es, this message translates to:
  /// **'Regresar a la orden'**
  String get splitReturnItemAction;

  /// No description provided for @splitAccountTotalLabel.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get splitAccountTotalLabel;

  /// No description provided for @confirmSplitAction.
  ///
  /// In es, this message translates to:
  /// **'Confirmar separación'**
  String get confirmSplitAction;

  /// No description provided for @splitAccountsConfirmedMessage.
  ///
  /// In es, this message translates to:
  /// **'Cuentas separadas listas para facturar.'**
  String get splitAccountsConfirmedMessage;

  /// No description provided for @splitAccountPaymentsTitle.
  ///
  /// In es, this message translates to:
  /// **'Pago por cuenta'**
  String get splitAccountPaymentsTitle;

  /// No description provided for @checkoutSuccessTitle.
  ///
  /// In es, this message translates to:
  /// **'Venta registrada'**
  String get checkoutSuccessTitle;

  /// No description provided for @checkoutSuccessMessage.
  ///
  /// In es, this message translates to:
  /// **'La venta se guardó localmente.'**
  String get checkoutSuccessMessage;

  /// No description provided for @businessSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos del negocio'**
  String get businessSettingsTitle;

  /// No description provided for @businessNameField.
  ///
  /// In es, this message translates to:
  /// **'Nombre comercial'**
  String get businessNameField;

  /// No description provided for @legalNameField.
  ///
  /// In es, this message translates to:
  /// **'Razón social'**
  String get legalNameField;

  /// No description provided for @taxNumberField.
  ///
  /// In es, this message translates to:
  /// **'RUC'**
  String get taxNumberField;

  /// No description provided for @phoneField.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get phoneField;

  /// No description provided for @addressField.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get addressField;

  /// No description provided for @invoicePrefixField.
  ///
  /// In es, this message translates to:
  /// **'Prefijo de factura'**
  String get invoicePrefixField;

  /// No description provided for @initialInvoiceNumberField.
  ///
  /// In es, this message translates to:
  /// **'Número inicial'**
  String get initialInvoiceNumberField;

  /// No description provided for @showCompanyInfoOnPdfField.
  ///
  /// In es, this message translates to:
  /// **'Mostrar datos de empresa en PDF'**
  String get showCompanyInfoOnPdfField;

  /// No description provided for @settingsSavedMessage.
  ///
  /// In es, this message translates to:
  /// **'Configuración guardada.'**
  String get settingsSavedMessage;

  /// No description provided for @emptyRolesTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin roles'**
  String get emptyRolesTitle;

  /// No description provided for @emptyRolesMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea roles y asigna permisos para controlar el acceso.'**
  String get emptyRolesMessage;

  /// No description provided for @emptyUsersTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin usuarios'**
  String get emptyUsersTitle;

  /// No description provided for @emptyUsersMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea usuarios locales y asígnales un rol.'**
  String get emptyUsersMessage;

  /// No description provided for @emptyAuditTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin eventos'**
  String get emptyAuditTitle;

  /// No description provided for @emptyAuditMessage.
  ///
  /// In es, this message translates to:
  /// **'No hay acciones auditadas para la fecha seleccionada.'**
  String get emptyAuditMessage;

  /// No description provided for @auditActionCategorySaved.
  ///
  /// In es, this message translates to:
  /// **'CategorÃ­a guardada'**
  String get auditActionCategorySaved;

  /// No description provided for @auditActionProductSaved.
  ///
  /// In es, this message translates to:
  /// **'Producto guardado'**
  String get auditActionProductSaved;

  /// No description provided for @auditActionPaymentMethodSaved.
  ///
  /// In es, this message translates to:
  /// **'MÃ©todo de pago guardado'**
  String get auditActionPaymentMethodSaved;

  /// No description provided for @auditActionTableSaved.
  ///
  /// In es, this message translates to:
  /// **'Mesa guardada'**
  String get auditActionTableSaved;

  /// No description provided for @auditActionSaleVoided.
  ///
  /// In es, this message translates to:
  /// **'Venta anulada'**
  String get auditActionSaleVoided;

  /// No description provided for @auditActionCashOpened.
  ///
  /// In es, this message translates to:
  /// **'Caja abierta'**
  String get auditActionCashOpened;

  /// No description provided for @auditActionCashClosed.
  ///
  /// In es, this message translates to:
  /// **'Caja cerrada'**
  String get auditActionCashClosed;

  /// No description provided for @auditActionExpenseCategorySaved.
  ///
  /// In es, this message translates to:
  /// **'CategorÃ­a de gasto guardada'**
  String get auditActionExpenseCategorySaved;

  /// No description provided for @auditActionExpenseCategoryDeleted.
  ///
  /// In es, this message translates to:
  /// **'Categoría de gasto eliminada'**
  String get auditActionExpenseCategoryDeleted;

  /// No description provided for @auditActionExpenseSaved.
  ///
  /// In es, this message translates to:
  /// **'Gasto registrado'**
  String get auditActionExpenseSaved;

  /// No description provided for @auditActionSettingsSaved.
  ///
  /// In es, this message translates to:
  /// **'ConfiguraciÃ³n guardada'**
  String get auditActionSettingsSaved;

  /// No description provided for @auditActionRoleSaved.
  ///
  /// In es, this message translates to:
  /// **'Rol guardado'**
  String get auditActionRoleSaved;

  /// No description provided for @auditActionUserSaved.
  ///
  /// In es, this message translates to:
  /// **'Usuario guardado'**
  String get auditActionUserSaved;

  /// No description provided for @auditDetailReason.
  ///
  /// In es, this message translates to:
  /// **'Motivo'**
  String get auditDetailReason;

  /// No description provided for @auditDetailStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get auditDetailStatus;

  /// No description provided for @auditDetailOptionGroups.
  ///
  /// In es, this message translates to:
  /// **'Grupos de opciones'**
  String get auditDetailOptionGroups;

  /// No description provided for @auditDetailPermissions.
  ///
  /// In es, this message translates to:
  /// **'Permisos'**
  String get auditDetailPermissions;

  /// No description provided for @emptySyncTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin pendientes'**
  String get emptySyncTitle;

  /// No description provided for @emptySyncMessage.
  ///
  /// In es, this message translates to:
  /// **'No hay operaciones locales pendientes de sincronizar.'**
  String get emptySyncMessage;

  /// No description provided for @syncNowAction.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar ahora'**
  String get syncNowAction;

  /// No description provided for @syncOperationCreate.
  ///
  /// In es, this message translates to:
  /// **'Registro nuevo'**
  String get syncOperationCreate;

  /// No description provided for @syncOperationUpdate.
  ///
  /// In es, this message translates to:
  /// **'Actualización'**
  String get syncOperationUpdate;

  /// No description provided for @syncOperationDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminación'**
  String get syncOperationDelete;

  /// No description provided for @syncStatusPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get syncStatusPending;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In es, this message translates to:
  /// **'Sincronizando'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusSynced.
  ///
  /// In es, this message translates to:
  /// **'Sincronizado'**
  String get syncStatusSynced;

  /// No description provided for @syncStatusError.
  ///
  /// In es, this message translates to:
  /// **'Con error'**
  String get syncStatusError;

  /// No description provided for @syncLastError.
  ///
  /// In es, this message translates to:
  /// **'Último error'**
  String get syncLastError;

  /// No description provided for @syncRetryCount.
  ///
  /// In es, this message translates to:
  /// **'Reintentos: {count}'**
  String syncRetryCount(int count);

  /// No description provided for @syncSummary.
  ///
  /// In es, this message translates to:
  /// **'Procesadas: {processed} | Correctas: {succeeded} | Fallidas: {failed}'**
  String syncSummary(int processed, int succeeded, int failed);

  /// No description provided for @createRoleTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo rol'**
  String get createRoleTitle;

  /// No description provided for @editRoleTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar rol'**
  String get editRoleTitle;

  /// No description provided for @roleDescriptionField.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get roleDescriptionField;

  /// No description provided for @systemRoleField.
  ///
  /// In es, this message translates to:
  /// **'Rol del sistema'**
  String get systemRoleField;

  /// No description provided for @permissionsSection.
  ///
  /// In es, this message translates to:
  /// **'Permisos'**
  String get permissionsSection;

  /// No description provided for @createUserTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo usuario'**
  String get createUserTitle;

  /// No description provided for @editUserTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar usuario'**
  String get editUserTitle;

  /// No description provided for @displayNameField.
  ///
  /// In es, this message translates to:
  /// **'Nombre visible'**
  String get displayNameField;

  /// No description provided for @emailField.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get emailField;

  /// No description provided for @pinField.
  ///
  /// In es, this message translates to:
  /// **'PIN'**
  String get pinField;

  /// No description provided for @pinOptionalField.
  ///
  /// In es, this message translates to:
  /// **'PIN nuevo (opcional)'**
  String get pinOptionalField;

  /// No description provided for @posUserField.
  ///
  /// In es, this message translates to:
  /// **'Usuario POS'**
  String get posUserField;

  /// No description provided for @posUserHelp.
  ///
  /// In es, this message translates to:
  /// **'Al iniciar sesion entra directo al flujo operativo del POS.'**
  String get posUserHelp;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesion'**
  String get loginTitle;

  /// No description provided for @loginMessage.
  ///
  /// In es, this message translates to:
  /// **'Ingresa con tu correo y PIN para operar SmooControl.'**
  String get loginMessage;

  /// No description provided for @loginAction.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get loginAction;

  /// No description provided for @initialAdminTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear administrador inicial'**
  String get initialAdminTitle;

  /// No description provided for @initialAdminMessage.
  ///
  /// In es, this message translates to:
  /// **'No hay usuarios con PIN. Crea el primer administrador para activar el acceso.'**
  String get initialAdminMessage;

  /// No description provided for @createInitialAdminAction.
  ///
  /// In es, this message translates to:
  /// **'Crear administrador'**
  String get createInitialAdminAction;

  /// No description provided for @accessDeniedTitle.
  ///
  /// In es, this message translates to:
  /// **'Acceso restringido'**
  String get accessDeniedTitle;

  /// No description provided for @accessDeniedMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu usuario no tiene permisos para abrir esta pantalla.'**
  String get accessDeniedMessage;

  /// No description provided for @roleField.
  ///
  /// In es, this message translates to:
  /// **'Rol'**
  String get roleField;

  /// No description provided for @noRoleAvailableMessage.
  ///
  /// In es, this message translates to:
  /// **'Primero crea un rol activo.'**
  String get noRoleAvailableMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
