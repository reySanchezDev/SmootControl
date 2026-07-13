import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/data/services/supabase_monthly_operational_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/monthly_operational_report.dart';

void main() {
  group('SupabaseMonthlyOperationalReportService', () {
    test('builds sales, expenses and payroll comparison', () async {
      final service = SupabaseMonthlyOperationalReportService(
        client: _FakeClient(_responseFor),
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://example.supabase.co',
          publishableKey: 'public-key',
        ),
        remoteSessionService: _remoteSession(),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
      );

      final result = await service.load(
        from: DateTime(2026, 7),
        to: DateTime(2026, 7, 15),
      );

      expect(result, isA<AppSuccess<MonthlyOperationalReport>>());
      final report = (result as AppSuccess<MonthlyOperationalReport>).value;
      expect(report.totalSalesInCents, 15000);
      expect(report.totalCostInCents, 5000);
      expect(report.grossProfitInCents, 10000);
      expect(report.consideredExpensesInCents, 2500);
      expect(report.excludedExpensesInCents, 4000);
      expect(report.payrollNetInCents, 6000);
      expect(report.payrollPaidInCents, 3000);
      expect(report.payrollBalanceInCents, 3000);
      expect(report.advancesDeliveredInCents, 1000);
      expect(report.pendingStaffConsumptionInCents, 1200);
      expect(report.operationalResultInCents, 1500);
      expect(report.dailyRows.first.resultInCents, 7500);
      expect(
        report.consideredExpensesByCategory.single.categoryName,
        'Operativo / Transporte',
      );
    });
  });
}

CurrentRemoteSessionService _remoteSession() {
  return CurrentRemoteSessionService()..set(
    accessToken: 'remote-token',
    userId: 'admin-user',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}

Future<http.Response> _responseFor(http.BaseRequest request) async {
  expect(request.headers['authorization'], 'Bearer remote-token');
  final path = request.url.path;
  if (path.endsWith('/sales')) return _salesResponse(request.url);
  if (path.endsWith('/sale_items')) {
    return _json([
      {'sale_id': 'sale-1', 'quantity': 2, 'unit_cost': 25},
    ]);
  }
  if (path.endsWith('/expense_categories')) return _categoriesResponse();
  if (path.endsWith('/operating_expenses')) return _expensesResponse();
  if (path.endsWith('/payroll_runs')) {
    return _json([
      {'id': 'payroll-1'},
    ]);
  }
  if (path.endsWith('/payroll_run_lines')) {
    return _json([
      {
        'net_pay': 60,
        'paid_amount': 30,
        'balance_amount': 30,
      },
    ]);
  }
  if (path.endsWith('/employee_salary_advances')) {
    return _json([
      {'amount': 10},
    ]);
  }
  fail('Unexpected request ${request.url}');
}

http.Response _salesResponse(Uri url) {
  if (url.queryParameters['sale_kind'] == 'eq.staff_consumption') {
    return _json([
      {'total_amount': 12},
    ]);
  }
  return _json([
    {
      'id': 'sale-1',
      'total_amount': 150,
      'sold_at': '2026-07-01T10:00:00Z',
    },
  ]);
}

http.Response _categoriesResponse() {
  return _json([
    {
      'id': 'root-ops',
      'name': 'Operativo',
      'parent_id': null,
      'include_in_gross_profit_coverage': false,
    },
    {
      'id': 'child-transport',
      'name': 'Transporte',
      'parent_id': 'root-ops',
      'include_in_gross_profit_coverage': true,
    },
    {
      'id': 'root-provider',
      'name': 'Proveedor',
      'parent_id': null,
      'include_in_gross_profit_coverage': false,
    },
  ]);
}

http.Response _expensesResponse() {
  return _json([
    {
      'id': 'expense-1',
      'expense_category_id': 'child-transport',
      'amount': 25,
      'spent_at': '2026-07-01T11:00:00Z',
    },
    {
      'id': 'expense-2',
      'expense_category_id': 'root-provider',
      'amount': 40,
      'spent_at': '2026-07-01T12:00:00Z',
    },
  ]);
}

http.Response _json(List<Map<String, Object?>> rows) {
  return http.Response(
    jsonEncode(rows),
    200,
    headers: {'content-type': 'application/json'},
  );
}

final class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
