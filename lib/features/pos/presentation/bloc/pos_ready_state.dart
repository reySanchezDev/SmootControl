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

  /// Current ticket total in cents.
  int get totalInCents {
    return cartLines.fold(0, (total, line) => total + line.totalInCents);
  }

  /// Internal key used to store the active cart.
  String get activeCartKey => selectedTableId ?? '__no_table__';

  /// Selected sales type for the active order.
  SalesType? get selectedSalesType {
    final selectedId =
        selectedSalesTypeId ?? salesTypeIdByOrderKey[activeCartKey];
    for (final type in salesTypes) {
      if (type.id == selectedId) return type;
    }
    for (final type in salesTypes) {
      if (type.isDefault && type.isActive) return type;
    }
    for (final type in salesTypes) {
      if (type.isActive) return type;
    }
    return null;
  }

  /// Whether the current cart was separated into named accounts.
  bool get hasSplitAccounts => splitAccounts.isNotEmpty;

  /// Unit-level draft items used by the split-account flow.
  List<SaleItemDraft> get splitDraftItems {
    final items = <SaleItemDraft>[];
    for (final line in cartLines) {
      for (var index = 0; index < line.quantity; index += 1) {
        final itemId = '${line.lineKey}-$index';
        items.add(
          SaleItemDraft(
            id: itemId,
            productId: line.product.id,
            productName: line.product.name,
            selectedOptionsLabel: line.selectedOptionsLabel.isEmpty
                ? null
                : line.selectedOptionsLabel,
            quantity: 1,
            unitPriceInCents: line.product.priceInCents,
          ),
        );
      }
    }
    return items;
  }

  /// Current selected category.
  ProductCategory? get selectedCategory {
    for (final category in categories) {
      if (category.id == selectedCategoryId) {
        return category;
      }
    }
    return null;
  }

  /// Parent category identifier used by the POS back action.
  String? get parentCategoryId => selectedCategory?.parentId;

  /// Categories visible at the current navigation level.
  List<ProductCategory> get visibleCategories {
    final visible =
        categories
            .where(
              (category) =>
                  category.isActive && category.parentId == selectedCategoryId,
            )
            .toList()
          ..sort(
            (first, second) => first.sortOrder.compareTo(second.sortOrder),
          );
    return visible;
  }

  /// Products visible at the current navigation level.
  List<Product> get visibleProducts {
    final activeProducts = products.where((product) {
      return product.isActive && product.isAvailableInPos;
    });
    if (categories.isEmpty) {
      return activeProducts.toList();
    }
    if (selectedCategoryId == null) {
      return const [];
    }
    return activeProducts
        .where((product) => product.categoryId == selectedCategoryId)
        .toList();
  }

  /// Resolves reusable and legacy option groups for one product.
  List<ProductOptionGroup> optionGroupsFor(Product product) {
    return PosOptionGroupResolver.resolve(
      product: product,
      modifierCatalog: modifierCatalog,
    );
  }

  /// Returns selected payment method.
  PaymentMethod? get selectedPaymentMethod {
    for (final method in paymentMethods) {
      if (method.id == selectedPaymentMethodId) {
        return method;
      }
    }
    return null;
  }

  /// Returns selected table.
  RestaurantTable? get selectedTable {
    for (final table in tables) {
      if (table.id == selectedTableId) {
        return table;
      }
    }
    return null;
  }

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
