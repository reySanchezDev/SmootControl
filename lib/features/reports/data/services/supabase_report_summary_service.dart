import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/core/utils/business_date_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/report_period.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';
import 'package:smoo_control/features/reports/domain/services/i_remote_report_summary_service.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';

part 'supabase_report_summary_http_part.dart';
part 'supabase_report_summary_mappers_part.dart';
part 'supabase_report_summary_models_part.dart';
part 'supabase_report_summary_queries_part.dart';

/// Builds administrative report summaries directly from Supabase.
final class SupabaseReportSummaryService
    implements IRemoteReportSummaryService {
  /// Creates a Supabase-backed report service.
  SupabaseReportSummaryService({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
  }) : _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;

  @override
  bool get isConfigured =>
      _remoteSessionService.hasUsableToken &&
      _config.isConfigured &&
      _restaurantService.isConfigured;

  @override
  Future<AppResult<ReportSummary>> loadSummaryForRange(
    ReportDateRange range,
  ) async {
    if (!isConfigured) {
      return const AppFailureResult(
        AppFailure(
          code: 'remote_reports_not_configured',
          message: 'Supabase no esta configurado para reportes.',
        ),
      );
    }

    try {
      final sales = await _loadSales(range);
      final completedSales = sales
          .where((sale) => sale.status == 'completed')
          .toList();
      final items = await _loadSaleItems(
        completedSales.map((sale) => sale.id).toSet(),
      );
      final expenses = await _loadExpenses(range);
      final categories = await _loadExpenseCategories();
      final sessions = await _loadCashRegisterSessions(range);
      final cashPaymentMethodIds = await _loadCashPaymentMethodIds();
      final voids = await _loadSaleVoids(range);

      final grossSales = completedSales.fold(
        0,
        (total, sale) => total + sale.totalInCents,
      );
      final grossProfit = items.fold(
        0,
        (total, item) => total + item.totalInCents - item.totalCostInCents,
      );
      final expensesTotal = expenses.fold(
        0,
        (total, expense) => total + expense.amountInCents,
      );
      final averageTicket = completedSales.isEmpty
          ? 0
          : grossSales ~/ completedSales.length;
      final productRanking = _rankProducts(items);

      final expensesBySession = <String, int>{};
      for (final expense in expenses) {
        final sessionId = expense.cashRegisterSessionId;
        if (sessionId == null) continue;
        expensesBySession[sessionId] =
            (expensesBySession[sessionId] ?? 0) + expense.amountInCents;
      }

      final cashSalesBySession = <String, int>{};
      for (final sale in completedSales) {
        final sessionId = sale.cashRegisterSessionId;
        if (sessionId == null) continue;
        if (!cashPaymentMethodIds.contains(sale.paymentMethodId)) continue;
        cashSalesBySession[sessionId] =
            (cashSalesBySession[sessionId] ?? 0) + sale.totalInCents;
      }

      var cashOpening = 0;
      var cashSales = 0;
      var cashExpenses = 0;
      var cashExpected = 0;
      var cashPhysical = 0;
      var cashDifference = 0;

      for (final session in sessions) {
        final sessionCashSales = cashSalesBySession[session.id] ?? 0;
        final sessionExpenses = expensesBySession[session.id] ?? 0;
        final expected =
            session.openingCashInCents + sessionCashSales - sessionExpenses;
        final physical = session.physicalClosingCashInCents ?? 0;

        cashOpening += session.openingCashInCents;
        cashSales += sessionCashSales;
        cashExpenses += sessionExpenses;
        cashExpected += expected;
        cashPhysical += physical;
        if (session.physicalClosingCashInCents != null) {
          cashDifference += physical - expected;
        }
      }

      return AppSuccess(
        ReportSummary(
          from: range.from,
          to: range.to,
          cashDifferenceInCents: cashDifference,
          cashExpectedInCents: cashExpected,
          cashExpensesInCents: cashExpenses,
          cashOpeningInCents: cashOpening,
          cashPhysicalInCents: cashPhysical,
          cashSalesInCents: cashSales,
          cashSessionsCount: sessions.length,
          salesCount: completedSales.length,
          voidsCount: voids.length,
          grossSalesInCents: grossSales,
          grossProfitInCents: grossProfit,
          expensesInCents: expensesTotal,
          expenses: _expenseDetails(expenses, categories),
          netProfitInCents: grossProfit - expensesTotal,
          averageTicketInCents: averageTicket,
          topProducts: productRanking,
          lowestProducts: productRanking.reversed.toList(),
          voids: voids,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_reports_failed',
          message: 'No se pudieron consultar los reportes en Supabase.',
          cause: error,
        ),
      );
    }
  }
}
