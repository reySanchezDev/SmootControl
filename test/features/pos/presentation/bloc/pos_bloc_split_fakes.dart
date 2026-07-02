part of 'pos_bloc_split_test.dart';

final class _CatalogFake implements ICatalogRepository {
  @override
  Future<AppResult<List<ProductCategory>>> getCategories() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<ProductCategory>> saveCategory(
    ProductCategory category,
  ) async {
    return AppSuccess(category);
  }

  @override
  Future<AppResult<ProductCategory>> removeCategoryLevel(
    ProductCategory category,
  ) async {
    return AppSuccess(category);
  }
}

final class _ProductsFake implements IProductsRepository {
  @override
  Future<AppResult<List<Product>>> getProducts() async {
    return const AppSuccess([_product]);
  }

  @override
  Future<AppResult<Product>> saveProduct(Product product) async {
    return AppSuccess(product);
  }
}

final class _InventoryFake implements IInventoryRepository {
  const _InventoryFake();

  @override
  Future<AppResult<List<InventoryStockItem>>> getTrackedStock() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<void>> registerPurchase({
    required String productId,
    required int quantity,
    required String userId,
    String? notes,
  }) async {
    return const AppSuccess<void>(null);
  }
}

final class _TablesFake implements ITablesRepository {
  @override
  Future<AppResult<List<RestaurantTable>>> getTables() async {
    return const AppSuccess([_table]);
  }

  @override
  Future<AppResult<RestaurantTable>> saveTable(RestaurantTable table) async {
    return AppSuccess(table);
  }

  @override
  Future<AppResult<List<TableAccount>>> getTableAccounts(String tableId) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<TableAccount>>> saveTableAccounts(
    List<TableAccount> accounts,
  ) async {
    return AppSuccess(accounts);
  }
}

final class _PaymentMethodsFake implements IPaymentMethodsRepository {
  @override
  Future<AppResult<List<PaymentMethod>>> getPaymentMethods() async {
    return const AppSuccess([_cashMethod, _transferMethod]);
  }

  @override
  Future<AppResult<PaymentMethod>> savePaymentMethod(
    PaymentMethod method,
  ) async {
    return AppSuccess(method);
  }

  @override
  Future<AppResult<PaymentMethod>> removePaymentMethodLevel(
    PaymentMethod method,
  ) async {
    return AppSuccess(method);
  }
}

final class _ModifiersFake implements IModifiersRepository {
  const _ModifiersFake();

  @override
  Future<AppResult<ModifierCatalog>> getCatalog() async {
    return const AppSuccess(ModifierCatalog(groups: [], options: []));
  }

  @override
  Future<AppResult<ModifierGroup>> saveGroup(ModifierGroup group) async {
    return AppSuccess(group);
  }

  @override
  Future<AppResult<ModifierOption>> saveOption(ModifierOption option) async {
    return AppSuccess(option);
  }
}

final class _SalesFake implements ISalesRepository {
  @override
  Future<AppResult<List<Sale>>> getSales({
    required DateTime from,
    required DateTime to,
  }) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<Sale>>> getSalesByCashRegisterSession(
    String sessionId,
  ) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<SaleItem>>> getSaleItems(String saleId) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<SaleVoid>>> getSaleVoids({
    required DateTime from,
    required DateTime to,
  }) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<Sale>> saveSale({
    required Sale sale,
    required List<SaleItem> items,
  }) async {
    return AppSuccess(sale);
  }

  @override
  Future<AppResult<Sale>> voidSale({
    required String saleId,
    required String reason,
    required String voidedBy,
  }) async {
    return const AppFailureResult(
      AppFailure(code: 'unsupported', message: 'Operacion no usada.'),
    );
  }
}

final class _SettingsFake implements IBusinessSettingsRepository {
  BusinessSettings _settings = const BusinessSettings(
    businessName: 'Casa del Cafe',
    showCompanyInfoOnReceipts: true,
    invoicePrefix: 'F',
    initialInvoiceNumber: 1,
    nextInvoiceNumber: 1,
  );

  @override
  Future<AppResult<BusinessSettings>> getSettings() async {
    return AppSuccess(_settings);
  }

  @override
  Future<AppResult<BusinessSettings>> saveSettings(
    BusinessSettings settings,
  ) async {
    _settings = settings;
    return AppSuccess(settings);
  }
}

final class _CashFake implements ICashRegisterRepository {
  const _CashFake(this._session);

  final CashRegisterSession _session;

  @override
  Future<AppResult<CashRegisterSession>> openSession(
    CashRegisterSession session,
  ) async {
    return AppSuccess(session);
  }

  @override
  Future<AppResult<CashRegisterSession?>> getOpenSession(
    DateTime businessDate,
  ) async {
    return AppSuccess(_session);
  }

  @override
  Future<AppResult<CashRegisterSession?>> getOpenSessionForCashier({
    required DateTime businessDate,
    required String cashierId,
  }) async {
    return AppSuccess(_session);
  }

  @override
  Future<AppResult<CashRegisterSession?>> getAnyOpenSessionForCashier(
    String cashierId,
  ) async {
    return AppSuccess(_session);
  }

  @override
  Future<AppResult<List<CashRegisterSession>>> getSessions({
    required DateTime from,
    required DateTime to,
  }) async {
    return AppSuccess([_session]);
  }

  @override
  Future<AppResult<CashRegisterSummary>> getSummary(
    CashRegisterSession session,
  ) async {
    return AppSuccess(
      CashRegisterSummary(
        session: session,
        cashSalesInCents: 0,
        expensesInCents: 0,
      ),
    );
  }

  @override
  Future<AppResult<CashRegisterSession>> closeSession({
    required String sessionId,
    required int physicalClosingCashInCents,
  }) async {
    return AppSuccess(_session);
  }
}

final class _AuditLogFake implements IAuditLogRepository {
  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    return AppSuccess(entry);
  }
}

final class _PosOpenTicketFake implements IPosOpenTicketRepository {
  @override
  Future<AppResult<void>> clearOrderContext(String orderKey) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<void>> clearAllOpenOrders() async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<List<PosOpenTicketLine>>> getOpenTickets() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<Map<String, String>>> getOrderSalesTypes() async {
    return const AppSuccess({});
  }

  @override
  Future<AppResult<void>> saveOrderSalesType({
    required String orderKey,
    required String salesTypeId,
  }) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<void>> saveTableTicket({
    required String tableId,
    required List<PosCartLine> lines,
  }) async {
    return const AppSuccess<void>(null);
  }
}

final class _PackagingRepositoryFake implements IPackagingRepository {
  const _PackagingRepositoryFake();

  @override
  Future<AppResult<List<SalesType>>> getSalesTypes() async {
    return const AppSuccess([
      SalesType(
        id: 'sales-type-dine-in',
        code: 'dine_in',
        name: 'Comer aqui',
        displayOrder: 0,
        isDefault: true,
        isActive: true,
      ),
    ]);
  }

  @override
  Future<AppResult<SalesType>> saveSalesType(SalesType salesType) async {
    return AppSuccess(salesType);
  }

  @override
  Future<AppResult<List<PackagingItem>>> getPackagingItems() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<PackagingItem>> savePackagingItem(
    PackagingItem item,
  ) async {
    return AppSuccess(item);
  }

  @override
  Future<AppResult<List<ProductPackagingRule>>> getRules() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<ProductPackagingRule>> saveRule(
    ProductPackagingRule rule,
  ) async {
    return AppSuccess(rule);
  }

  @override
  Future<AppResult<List<PackagingStockItem>>> getPackagingStock() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<void>> registerPackagingPurchase({
    required String packagingItemId,
    required int quantity,
    required String userId,
    String? notes,
  }) async {
    return const AppSuccess<void>(null);
  }
}
