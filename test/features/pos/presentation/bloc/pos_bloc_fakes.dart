part of 'pos_bloc_test.dart';

final class _CatalogRepositoryFake implements ICatalogRepository {
  const _CatalogRepositoryFake({required this.categoriesResult});

  final AppResult<List<ProductCategory>> categoriesResult;

  @override
  Future<AppResult<List<ProductCategory>>> getCategories() async {
    return categoriesResult;
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

final class _ProductsRepositoryFake implements IProductsRepository {
  const _ProductsRepositoryFake({required this.productsResult});

  final AppResult<List<Product>> productsResult;

  @override
  Future<AppResult<List<Product>>> getProducts() async => productsResult;

  @override
  Future<AppResult<Product>> saveProduct(Product product) async {
    return AppSuccess(product);
  }
}

final class _TablesRepositoryFake implements ITablesRepository {
  const _TablesRepositoryFake({required this.tablesResult});

  final AppResult<List<RestaurantTable>> tablesResult;

  @override
  Future<AppResult<List<RestaurantTable>>> getTables() async {
    return tablesResult;
  }

  @override
  Future<AppResult<RestaurantTable>> saveTable(
    RestaurantTable table,
  ) async {
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

final class _PaymentMethodsRepositoryFake implements IPaymentMethodsRepository {
  const _PaymentMethodsRepositoryFake({required this.methodsResult});

  final AppResult<List<PaymentMethod>> methodsResult;

  @override
  Future<AppResult<List<PaymentMethod>>> getPaymentMethods() async {
    return methodsResult;
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

final class _ModifiersRepositoryFake implements IModifiersRepository {
  const _ModifiersRepositoryFake();

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

class _SalesRepositoryFake implements ISalesRepository {
  final savedItemsBySaleId = <String, List<SaleItem>>{};

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
    savedItemsBySaleId[sale.id] = items;
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

final class _BlockingSalesRepositoryFake extends _SalesRepositoryFake {
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<void> _release = Completer<void>();

  @override
  Future<AppResult<Sale>> saveSale({
    required Sale sale,
    required List<SaleItem> items,
  }) async {
    if (!firstSaveStarted.isCompleted) {
      firstSaveStarted.complete();
    }
    await _release.future;
    return super.saveSale(sale: sale, items: items);
  }

  void complete() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }
}

final class _CashRegisterRepositoryFake implements ICashRegisterRepository {
  const _CashRegisterRepositoryFake(this._session);

  final CashRegisterSession? _session;

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
    return AppSuccess(_session == null ? const [] : [_session]);
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
    final session = _session;
    if (session == null) {
      throw StateError('No session');
    }

    return AppSuccess(session);
  }
}

final class _AuditLogRepositoryFake implements IAuditLogRepository {
  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    return AppSuccess(entry);
  }
}

final class _BusinessSettingsRepositoryFake
    implements IBusinessSettingsRepository {
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

final class _PosOpenTicketRepositoryFake implements IPosOpenTicketRepository {
  _PosOpenTicketRepositoryFake({
    List<PosOpenTicketLine> tickets = const [],
  }) : _tickets = [...tickets];

  final List<PosOpenTicketLine> _tickets;

  @override
  Future<AppResult<List<PosOpenTicketLine>>> getOpenTickets() async {
    return AppSuccess([..._tickets]);
  }

  @override
  Future<AppResult<void>> saveTableTicket({
    required String tableId,
    required List<PosCartLine> lines,
  }) async {
    _tickets
      ..removeWhere((ticket) => ticket.tableId == tableId)
      ..addAll([
        for (final line in lines)
          PosOpenTicketLine(
            lineKey: line.lineKey,
            tableId: tableId,
            productId: line.product.id,
            quantity: line.quantity,
            isServed: line.isServed,
            selectedOptions: line.selectedOptions,
          ),
      ]);
    return const AppSuccess<void>(null);
  }
}
