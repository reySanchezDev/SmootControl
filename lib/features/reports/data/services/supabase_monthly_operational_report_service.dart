import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/domain/entities/monthly_operational_report.dart';

part 'supabase_monthly_operational_report_models_part.dart';
part 'supabase_monthly_operational_report_queries_part.dart';

/// Builds the monthly operational result report from Supabase.
final class SupabaseMonthlyOperationalReportService {
  /// Creates the remote service.
  const SupabaseMonthlyOperationalReportService({
    required http.Client client,
    required SupabaseAppConfig config,
    required CurrentRemoteSessionService remoteSessionService,
    required CurrentRestaurantService restaurantService,
  }) : _client = client,
       _config = config,
       _remoteSessionService = remoteSessionService,
       _restaurantService = restaurantService;

  final http.Client _client;
  final SupabaseAppConfig _config;
  final CurrentRemoteSessionService _remoteSessionService;
  final CurrentRestaurantService _restaurantService;

  /// Loads one inclusive operational comparison range.
  Future<AppResult<MonthlyOperationalReport>> load({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_isConfigured) {
      return const AppFailureResult(
        AppFailure(
          code: 'monthly_operational_report_not_configured',
          message: 'Supabase no esta configurado para reportes.',
        ),
      );
    }

    final safeFrom = _dateOnly(from);
    final safeTo = _dateOnly(to);
    if (safeTo.isBefore(safeFrom)) {
      return const AppFailureResult(
        AppFailure(
          code: 'monthly_operational_report_invalid_range',
          message: 'La fecha final no puede ser menor que la fecha inicial.',
        ),
      );
    }

    try {
      final exclusiveTo = safeTo.add(const Duration(days: 1));
      final sales = await _loadSales(from: safeFrom, exclusiveTo: exclusiveTo);
      final saleItems = await _loadSaleItems(sales.map((sale) => sale.id));
      final categories = await _loadExpenseCategories();
      final expenses = await _loadExpenses(
        from: safeFrom,
        exclusiveTo: exclusiveTo,
      );
      final payroll = await _loadPayroll(from: safeFrom, to: safeTo);
      final advances = await _loadAdvances(
        from: safeFrom,
        exclusiveTo: exclusiveTo,
      );
      final pendingConsumption = await _loadPendingStaffConsumption(
        from: safeFrom,
        exclusiveTo: exclusiveTo,
      );

      return AppSuccess(
        _buildReport(
          advancesDeliveredInCents: advances,
          categories: categories,
          expenses: expenses,
          from: safeFrom,
          payroll: payroll,
          pendingStaffConsumptionInCents: pendingConsumption,
          saleItems: saleItems,
          sales: sales,
          to: safeTo,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'monthly_operational_report_failed',
          message: 'No se pudo consultar el resultado operativo.',
          cause: error,
        ),
      );
    }
  }

  bool get _isConfigured {
    return _config.isConfigured &&
        _restaurantService.isConfigured &&
        _remoteSessionService.hasUsableToken;
  }

  MonthlyOperationalReport _buildReport({
    required int advancesDeliveredInCents,
    required Map<String, _ExpenseCategory> categories,
    required List<_RemoteExpense> expenses,
    required DateTime from,
    required _PayrollTotals payroll,
    required int pendingStaffConsumptionInCents,
    required List<_RemoteSaleItem> saleItems,
    required List<_RemoteSale> sales,
    required DateTime to,
  }) {
    final dateBySaleId = {for (final sale in sales) sale.id: sale.date};
    final salesByDate = <DateTime, _DailyAccumulator>{};
    final expensesByCategory = <String, int>{};
    var excludedExpenses = 0;
    var totalCost = 0;

    for (final sale in sales) {
      salesByDate.putIfAbsent(sale.date, _DailyAccumulator.new).sales +=
          sale.totalInCents;
    }
    for (final item in saleItems) {
      final date = dateBySaleId[item.saleId];
      if (date == null) continue;
      salesByDate.putIfAbsent(date, _DailyAccumulator.new).cost +=
          item.costInCents;
      totalCost += item.costInCents;
    }
    for (final expense in expenses) {
      final category = categories[expense.categoryId];
      final affectsCoverage = category?.includeInCoverage ?? false;
      if (!affectsCoverage) {
        excludedExpenses += expense.amountInCents;
        continue;
      }
      salesByDate.putIfAbsent(expense.date, _DailyAccumulator.new).expenses +=
          expense.amountInCents;
      final name = _categoryPath(category, categories);
      expensesByCategory.update(
        name ?? 'Sin categoria',
        (current) => current + expense.amountInCents,
        ifAbsent: () => expense.amountInCents,
      );
    }

    return MonthlyOperationalReport(
      advancesDeliveredInCents: advancesDeliveredInCents,
      consideredExpensesByCategory: _expenseRows(expensesByCategory),
      dailyRows: _dailyRows(salesByDate),
      excludedExpensesInCents: excludedExpenses,
      from: from,
      payrollBalanceInCents: payroll.balance,
      payrollNetInCents: payroll.net,
      payrollPaidInCents: payroll.paid,
      pendingStaffConsumptionInCents: pendingStaffConsumptionInCents,
      totalCostInCents: totalCost,
      totalSalesInCents: sales.fold(0, (sum, sale) => sum + sale.totalInCents),
      to: to,
    );
  }

  List<MonthlyOperationalDailyRow> _dailyRows(
    Map<DateTime, _DailyAccumulator> values,
  ) {
    return values.entries.map((entry) {
      final value = entry.value;
      return MonthlyOperationalDailyRow(
        date: entry.key,
        expensesInCents: value.expenses,
        grossProfitInCents: value.sales - value.cost,
        salesInCents: value.sales,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  List<MonthlyOperationalExpenseRow> _expenseRows(Map<String, int> values) {
    return values.entries.map((entry) {
      return MonthlyOperationalExpenseRow(
        categoryName: entry.key,
        totalInCents: entry.value,
      );
    }).toList()..sort((a, b) => b.totalInCents.compareTo(a.totalInCents));
  }

  String? _categoryPath(
    _ExpenseCategory? category,
    Map<String, _ExpenseCategory> categories,
  ) {
    var current = category;
    if (current == null) return null;
    final names = <String>[];
    final visited = <String>{};
    while (current != null && visited.add(current.id)) {
      names.insert(0, current.name);
      current = categories[current.parentId];
    }
    return names.join(' / ');
  }
}
