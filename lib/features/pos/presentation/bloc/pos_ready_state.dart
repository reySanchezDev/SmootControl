part of 'pos_state.dart';

/// POS ready state with catalogs, table context and current ticket data.
final class PosReady extends PosState {
  /// Creates a ready POS state.
  const PosReady({
    required this.products,
    required this.paymentMethods,
    this.cartLines = const [],
    this.cartLinesByTable = const {},
    this.categories = const [],
    this.modifierCatalog = const ModifierCatalog(groups: [], options: []),
    this.splitAccounts = const [],
    this.splitAccountsByTable = const {},
    this.splitSourceLinesByTable = const {},
    this.tables = const [],
    this.salesTypes = const [],
    this.salesTypeIdByOrderKey = const {},
    this.productOrderByProductId = const {},
    this.tableOrderByTableId = const {},
    this.selectedCategoryId,
    this.selectedTableId,
    this.selectedSalesTypeId,
    this.selectedSplitAccountId,
    this.selectedPaymentMethodId,
    this.openCashRegisterSession,
    this.lastCompletedSale,
    this.lastCompletedSales = const [],
  });

  /// Categories and subcategories available in the POS navigation.
  final List<ProductCategory> categories;

  /// Products available to sell.
  final List<Product> products;

  /// Active restaurant tables available in the POS.
  final List<RestaurantTable> tables;

  /// Payment methods available for checkout.
  final List<PaymentMethod> paymentMethods;

  /// Local-only product display order preferences keyed by product id.
  final Map<String, int> productOrderByProductId;

  /// Local-only table display order preferences keyed by table id.
  final Map<String, int> tableOrderByTableId;

  /// Sales types available for the current order.
  final List<SalesType> salesTypes;

  /// Selected sales type by table/order key.
  final Map<String, String> salesTypeIdByOrderKey;

  /// Reusable modifier groups and options.
  final ModifierCatalog modifierCatalog;

  /// Lines shown in the active POS ticket.
  final List<PosCartLine> cartLines;

  /// Open ticket lines grouped by table.
  final Map<String, List<PosCartLine>> cartLinesByTable;

  /// Split accounts loaded for the selected table.
  final List<AccountSplitDraft> splitAccounts;

  /// Confirmed split accounts grouped by original table.
  final Map<String, List<AccountSplitDraft>> splitAccountsByTable;

  /// Original table ticket lines kept after account separation.
  final Map<String, List<PosCartLine>> splitSourceLinesByTable;

  /// Selected category identifier.
  final String? selectedCategoryId;

  /// Selected table identifier.
  final String? selectedTableId;

  /// Selected child account identifier, when charging a split account.
  final String? selectedSplitAccountId;

  /// Selected sales type for the active order.
  final String? selectedSalesTypeId;

  /// Selected payment method identifier.
  final String? selectedPaymentMethodId;

  /// Open cash register session for the current operator.
  final CashRegisterSession? openCashRegisterSession;

  /// Last completed sale, when checkout just succeeded.
  final Sale? lastCompletedSale;

  /// Last completed sales, when split checkout just succeeded.
  final List<Sale> lastCompletedSales;

  /// Creates a modified copy.
  PosReady copyWith({
    List<ProductCategory>? categories,
    List<Product>? products,
    List<RestaurantTable>? tables,
    List<SalesType>? salesTypes,
    Map<String, String>? salesTypeIdByOrderKey,
    List<PaymentMethod>? paymentMethods,
    Map<String, int>? productOrderByProductId,
    Map<String, int>? tableOrderByTableId,
    ModifierCatalog? modifierCatalog,
    List<PosCartLine>? cartLines,
    Map<String, List<PosCartLine>>? cartLinesByTable,
    List<AccountSplitDraft>? splitAccounts,
    Map<String, List<AccountSplitDraft>>? splitAccountsByTable,
    Map<String, List<PosCartLine>>? splitSourceLinesByTable,
    String? selectedCategoryId,
    String? selectedTableId,
    String? selectedSalesTypeId,
    String? selectedSplitAccountId,
    String? selectedPaymentMethodId,
    CashRegisterSession? openCashRegisterSession,
    Sale? lastCompletedSale,
    List<Sale>? lastCompletedSales,
    bool clearSelectedCategory = false,
    bool clearSelectedTable = false,
    bool clearSelectedSplitAccount = false,
    bool clearSplitAccounts = false,
    bool clearLastCompletedSale = false,
  }) {
    return PosReady(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      tables: tables ?? this.tables,
      salesTypes: salesTypes ?? this.salesTypes,
      salesTypeIdByOrderKey:
          salesTypeIdByOrderKey ?? this.salesTypeIdByOrderKey,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      productOrderByProductId:
          productOrderByProductId ?? this.productOrderByProductId,
      tableOrderByTableId: tableOrderByTableId ?? this.tableOrderByTableId,
      modifierCatalog: modifierCatalog ?? this.modifierCatalog,
      cartLines: cartLines ?? this.cartLines,
      cartLinesByTable: cartLinesByTable ?? this.cartLinesByTable,
      splitAccounts: clearSplitAccounts
          ? const []
          : splitAccounts ?? this.splitAccounts,
      splitAccountsByTable: splitAccountsByTable ?? this.splitAccountsByTable,
      splitSourceLinesByTable:
          splitSourceLinesByTable ?? this.splitSourceLinesByTable,
      selectedCategoryId: clearSelectedCategory
          ? null
          : selectedCategoryId ?? this.selectedCategoryId,
      selectedTableId: clearSelectedTable
          ? null
          : selectedTableId ?? this.selectedTableId,
      selectedSalesTypeId: selectedSalesTypeId ?? this.selectedSalesTypeId,
      selectedSplitAccountId: clearSelectedSplitAccount
          ? null
          : selectedSplitAccountId ?? this.selectedSplitAccountId,
      selectedPaymentMethodId:
          selectedPaymentMethodId ?? this.selectedPaymentMethodId,
      openCashRegisterSession:
          openCashRegisterSession ?? this.openCashRegisterSession,
      lastCompletedSale: clearLastCompletedSale
          ? null
          : lastCompletedSale ?? this.lastCompletedSale,
      lastCompletedSales: clearLastCompletedSale
          ? const []
          : lastCompletedSales ?? this.lastCompletedSales,
    );
  }

  @override
  List<Object?> get props => [
    categories,
    products,
    tables,
    salesTypes,
    salesTypeIdByOrderKey,
    paymentMethods,
    productOrderByProductId,
    tableOrderByTableId,
    modifierCatalog,
    cartLines,
    cartLinesByTable,
    splitAccounts,
    splitAccountsByTable,
    splitSourceLinesByTable,
    selectedCategoryId,
    selectedTableId,
    selectedSalesTypeId,
    selectedSplitAccountId,
    selectedPaymentMethodId,
    openCashRegisterSession,
    lastCompletedSale,
    lastCompletedSales,
  ];
}
