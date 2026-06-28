part of 'report_summary_service_test.dart';

final class _CashRegisterRepositoryFake implements ICashRegisterRepository {
  const _CashRegisterRepositoryFake({required this.summaries});

  final List<CashRegisterSummary> summaries;

  @override
  Future<AppResult<CashRegisterSession>> closeSession({
    required String sessionId,
    required int physicalClosingCashInCents,
  }) async {
    return AppSuccess(summaries.first.session);
  }

  @override
  Future<AppResult<CashRegisterSession?>> getOpenSession(
    DateTime businessDate,
  ) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<CashRegisterSession?>> getOpenSessionForCashier({
    required DateTime businessDate,
    required String cashierId,
  }) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<CashRegisterSession?>> getAnyOpenSessionForCashier(
    String cashierId,
  ) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<List<CashRegisterSession>>> getSessions({
    required DateTime from,
    required DateTime to,
  }) async {
    return AppSuccess(
      summaries.map((summary) => summary.session).where((session) {
        return !session.businessDate.isBefore(from) &&
            session.businessDate.isBefore(to);
      }).toList(),
    );
  }

  @override
  Future<AppResult<CashRegisterSummary>> getSummary(
    CashRegisterSession session,
  ) async {
    return AppSuccess(
      summaries.firstWhere((summary) => summary.session.id == session.id),
    );
  }

  @override
  Future<AppResult<CashRegisterSession>> openSession(
    CashRegisterSession session,
  ) async {
    return AppSuccess(session);
  }
}

final class _SalesRepositoryFake implements ISalesRepository {
  const _SalesRepositoryFake({
    required this.sales,
    required this.itemsBySaleId,
    this.voids = const [],
  });

  final Map<String, List<SaleItem>> itemsBySaleId;
  final List<Sale> sales;
  final List<SaleVoid> voids;

  @override
  Future<AppResult<List<Sale>>> getSales({
    required DateTime from,
    required DateTime to,
  }) async {
    return AppSuccess(
      sales.where((sale) {
        return !sale.createdAt.isBefore(from) && sale.createdAt.isBefore(to);
      }).toList(),
    );
  }

  @override
  Future<AppResult<List<Sale>>> getSalesByCashRegisterSession(
    String sessionId,
  ) async {
    return AppSuccess(
      sales.where((sale) => sale.cashRegisterSessionId == sessionId).toList(),
    );
  }

  @override
  Future<AppResult<List<SaleItem>>> getSaleItems(String saleId) async {
    return AppSuccess(itemsBySaleId[saleId] ?? []);
  }

  @override
  Future<AppResult<List<SaleVoid>>> getSaleVoids({
    required DateTime from,
    required DateTime to,
  }) async {
    return AppSuccess(
      voids.where((saleVoid) {
        return !saleVoid.voidedAt.isBefore(from) &&
            saleVoid.voidedAt.isBefore(to);
      }).toList(),
    );
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
    return AppSuccess(sales.first);
  }
}

final class _ExpensesRepositoryFake implements IExpensesRepository {
  const _ExpensesRepositoryFake({required this.expenses});

  final List<OperatingExpense> expenses;

  @override
  Future<AppResult<List<ExpenseCategory>>> getCategories() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<OperatingExpense>>> getExpenses({
    required DateTime from,
    required DateTime to,
  }) async {
    return AppSuccess(
      expenses.where((expense) {
        return !expense.createdAt.isBefore(from) &&
            expense.createdAt.isBefore(to);
      }).toList(),
    );
  }

  @override
  Future<AppResult<ExpenseCategory>> saveCategory(
    ExpenseCategory category,
  ) async {
    return AppSuccess(category);
  }

  @override
  Future<AppResult<void>> deleteCategory(String categoryId) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<OperatingExpense>> saveExpense(
    OperatingExpense expense,
  ) async {
    return AppSuccess(expense);
  }
}
