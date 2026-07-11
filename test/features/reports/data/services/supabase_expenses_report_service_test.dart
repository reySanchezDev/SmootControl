import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/data/services/supabase_expenses_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/expenses_report.dart';

void main() {
  group('SupabaseExpensesReportService', () {
    test('groups operational expenses by day and category', () async {
      final session = CurrentRemoteSessionService()
        ..set(
          accessToken: 'remote-token',
          userId: 'admin-user',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
      final service = SupabaseExpensesReportService(
        client: _FakeClient((request) async {
          expect(request.headers['authorization'], 'Bearer remote-token');
          if (request.url.path.endsWith('/expense_categories')) {
            return http.Response(
              jsonEncode([
                {'id': 'rent', 'name': 'Renta'},
                {'id': 'ops', 'name': 'Operativo'},
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.url.path.endsWith('/operating_expenses')) {
            expect(
              request.url.queryParameters['expense_kind'],
              'eq.operational',
            );
            return http.Response(
              jsonEncode([
                {
                  'id': 'expense-1',
                  'expense_category_id': 'rent',
                  'amount': 100,
                  'description': 'Renta',
                  'spent_at': '2026-07-01T10:00:00Z',
                },
                {
                  'id': 'expense-2',
                  'expense_category_id': 'ops',
                  'amount': 25,
                  'description': 'Compra',
                  'spent_at': '2026-07-01T14:00:00Z',
                },
                {
                  'id': 'expense-3',
                  'expense_category_id': 'ops',
                  'amount': 50,
                  'description': 'Compra',
                  'spent_at': '2026-07-02T09:00:00Z',
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          fail('Unexpected request ${request.url}');
        }),
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://example.supabase.co',
          publishableKey: 'public-key',
        ),
        remoteSessionService: session,
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
      );

      final result = await service.load(
        from: DateTime(2026, 7),
        to: DateTime(2026, 7, 2),
      );

      expect(result, isA<AppSuccess<ExpensesReport>>());
      final report = (result as AppSuccess<ExpensesReport>).value;
      expect(report.rows, hasLength(2));
      expect(report.rows.first.totalInCents, 12500);
      expect(report.rows.last.totalInCents, 5000);
      expect(report.totalInCents, 17500);
      expect(report.averageDailyInCents, 8750);
      expect(report.byCategory.first.categoryName, 'Renta');
      expect(report.byCategory.first.totalInCents, 10000);
      expect(report.byCategory.last.categoryName, 'Operativo');
      expect(report.byCategory.last.totalInCents, 7500);
    });
  });
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
