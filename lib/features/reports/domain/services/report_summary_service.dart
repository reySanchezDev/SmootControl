import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_summary.dart';
import 'package:smoo_control/features/cash_register/domain/repositories/i_cash_register_repository.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';
import 'package:smoo_control/features/expenses/domain/repositories/i_expenses_repository.dart';
import 'package:smoo_control/features/reports/domain/entities/report_period.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';

/// Builds business summaries from sales, sale details and expenses.
final class ReportSummaryService {
  /// Creates a report summary service.
  const ReportSummaryService({
    required ICashRegisterRepository cashRegisterRepository,
    required ISalesRepository salesRepository,
    required IExpensesRepository expensesRepository,
  }) : _cashRegisterRepository = cashRegisterRepository,
       _salesRepository = salesRepository,
       _expensesRepository = expensesRepository;

  final ICashRegisterRepository _cashRegisterRepository;
  final ISalesRepository _salesRepository;
  final IExpensesRepository _expensesRepository;

  /// Loads and calculates the report summary for a period.
  Future<AppResult<ReportSummary>> loadSummary({
    required ReportPeriod period,
    required DateTime now,
    ReportDateRange? customRange,
  }) async {
    final range = customRange ?? period.rangeFor(now);
    return loadSummaryForRange(range);
  }

  /// Loads and calculates the report summary for an explicit date range.
  Future<AppResult<ReportSummary>> loadSummaryForRange(
    ReportDateRange range,
  ) async {
    final salesResult = await _salesRepository.getSales(
      from: range.from,
      to: range.to,
    );
    final expensesResult = await _expensesRepository.getExpenses(
      from: range.from,
      to: range.to,
    );
    final voidsResult = await _salesRepository.getSaleVoids(
      from: range.from,
      to: range.to,
    );
    final cashSessionsResult = await _cashRegisterRepository.getSessions(
      from: range.from,
      to: range.to,
    );
    final categoriesResult = await _expensesRepository.getCategories();

    return switch ((
      salesResult,
      expensesResult,
      voidsResult,
      cashSessionsResult,
      categoriesResult,
    )) {
      (AppFailureResult<List<Sale>>(:final error), _, _, _, _) =>
        AppFailureResult(
          error,
        ),
      (_, AppFailureResult<List<OperatingExpense>>(:final error), _, _, _) =>
        AppFailureResult(error),
      (_, _, AppFailureResult<List<SaleVoid>>(:final error), _, _) =>
        AppFailureResult(error),
      (_, _, _, AppFailureResult<List<CashRegisterSession>>(:final error), _) =>
        AppFailureResult(error),
      (_, _, _, _, AppFailureResult<List<ExpenseCategory>>(:final error)) =>
        AppFailureResult(error),
      (
        AppSuccess<List<Sale>>(:final value),
        AppSuccess<List<OperatingExpense>>(value: final expenses),
        AppSuccess<List<SaleVoid>>(value: final voids),
        AppSuccess<List<CashRegisterSession>>(value: final cashSessions),
        AppSuccess<List<ExpenseCategory>>(value: final categories),
      ) =>
        await _buildSummary(
          from: range.from,
          to: range.to,
          sales: value,
          expenses: expenses,
          voids: voids,
          cashSessions: cashSessions,
          categories: categories,
        ),
    };
  }

  Future<AppResult<ReportSummary>> _buildSummary({
    required DateTime from,
    required DateTime to,
    required List<Sale> sales,
    required List<OperatingExpense> expenses,
    required List<SaleVoid> voids,
    required List<CashRegisterSession> cashSessions,
    required List<ExpenseCategory> categories,
  }) async {
    final completedSales = sales
        .where((sale) => sale.status == SaleStatus.completed)
        .toList();
    final allItems = <SaleItem>[];

    for (final sale in completedSales) {
      final itemsResult = await _salesRepository.getSaleItems(sale.id);

      switch (itemsResult) {
        case AppSuccess<List<SaleItem>>(:final value):
          allItems.addAll(value);
        case AppFailureResult<List<SaleItem>>(:final error):
          return AppFailureResult(error);
      }
    }

    final cashSummaries = <CashRegisterSummary>[];
    for (final session in cashSessions) {
      final result = await _cashRegisterRepository.getSummary(session);
      switch (result) {
        case AppSuccess<CashRegisterSummary>(:final value):
          cashSummaries.add(value);
        case AppFailureResult<CashRegisterSummary>(:final error):
          return AppFailureResult(error);
      }
    }

    final grossSales = completedSales.fold(
      0,
      (total, sale) => total + sale.totalInCents,
    );
    final grossProfit = allItems.fold(
      0,
      (total, item) => total + item.totalInCents - item.totalCostInCents,
    );
    final expensesTotal = expenses.fold(
      0,
      (total, expense) => total + expense.amountInCents,
    );
    final expenseDetails = _expenseDetails(expenses, categories);
    final averageTicket = completedSales.isEmpty
        ? 0
        : grossSales ~/ completedSales.length;

    final productRanking = _rankProducts(allItems);
    final cashOpening = cashSummaries.fold(
      0,
      (total, summary) => total + summary.session.openingCashInCents,
    );
    final cashSales = cashSummaries.fold(
      0,
      (total, summary) => total + summary.cashSalesInCents,
    );
    final cashExpenses = cashSummaries.fold(
      0,
      (total, summary) => total + summary.expensesInCents,
    );
    final cashExpected = cashSummaries.fold(
      0,
      (total, summary) => total + summary.expectedClosingCashInCents,
    );
    final cashPhysical = cashSummaries.fold(
      0,
      (total, summary) {
        return total + (summary.session.physicalClosingCashInCents ?? 0);
      },
    );
    final cashDifference = cashSummaries.fold(
      0,
      (total, summary) => total + (summary.differenceInCents ?? 0),
    );

    return AppSuccess(
      ReportSummary(
        from: from,
        to: to,
        cashDifferenceInCents: cashDifference,
        cashExpectedInCents: cashExpected,
        cashExpensesInCents: cashExpenses,
        cashOpeningInCents: cashOpening,
        cashPhysicalInCents: cashPhysical,
        cashSalesInCents: cashSales,
        cashSessionsCount: cashSessions.length,
        salesCount: completedSales.length,
        voidsCount: voids.length,
        grossSalesInCents: grossSales,
        grossProfitInCents: grossProfit,
        expensesInCents: expensesTotal,
        expenses: expenseDetails,
        netProfitInCents: grossProfit - expensesTotal,
        averageTicketInCents: averageTicket,
        topProducts: productRanking,
        lowestProducts: productRanking.reversed.toList(),
        voids: voids,
      ),
    );
  }

  List<ExpenseReportEntry> _expenseDetails(
    List<OperatingExpense> expenses,
    List<ExpenseCategory> categories,
  ) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    return expenses.map((expense) {
      final category = categoryById[expense.categoryId];
      return ExpenseReportEntry(
        id: expense.id,
        categoryId: expense.categoryId,
        categoryName: category?.name ?? 'Sin categoria',
        amountInCents: expense.amountInCents,
        description: expense.description,
        createdAt: expense.createdAt,
        createdBy: expense.createdBy,
      );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ProductSalesMetric> _rankProducts(List<SaleItem> items) {
    final metrics = <String, ProductSalesMetric>{};

    for (final item in items) {
      final current = metrics[item.productId];
      metrics[item.productId] = ProductSalesMetric(
        productId: item.productId,
        productName: item.productName,
        quantity: (current?.quantity ?? 0) + item.quantity,
        salesInCents: (current?.salesInCents ?? 0) + item.totalInCents,
        profitInCents:
            (current?.profitInCents ?? 0) +
            item.totalInCents -
            item.totalCostInCents,
      );
    }

    return metrics.values.toList()..sort((a, b) {
      final quantityComparison = b.quantity.compareTo(a.quantity);
      if (quantityComparison != 0) {
        return quantityComparison;
      }

      return b.salesInCents.compareTo(a.salesInCents);
    });
  }
}
