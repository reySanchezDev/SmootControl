import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/data/services/supabase_daily_sales_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/daily_sales_report.dart';

void main() {
  group('SupabaseDailySalesReportService', () {
    test(
      'groups completed normal sales by day with historical item cost',
      () async {
        final session = CurrentRemoteSessionService()
          ..set(
            accessToken: 'remote-token',
            userId: 'admin-user',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          );
        final service = SupabaseDailySalesReportService(
          client: _FakeClient((request) async {
            expect(request.headers['authorization'], 'Bearer remote-token');
            expect(
              request.url.path,
              endsWith('/rpc/app_get_daily_sales_report'),
            );
            final body = (request as http.Request).body;
            final payload =
                jsonDecode(body) as Map<String, dynamic>;
            expect(payload['p_restaurant_id'], 'restaurant-1');
            expect(payload['p_from'], '2026-07-01');
            expect(payload['p_to'], '2026-07-02');
            expect(payload['p_timezone'], 'America/Managua');

            if (request.url.path.endsWith('/rpc/app_get_daily_sales_report')) {
              return http.Response(
                jsonEncode([
                  {
                    'date': '2026-07-01',
                    'sales_amount': 150,
                    'cost_amount': 50,
                  },
                  {
                    'date': '2026-07-02',
                    'sales_amount': 80,
                    'cost_amount': 20,
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

        expect(result, isA<AppSuccess<DailySalesReport>>());
        final report = (result as AppSuccess<DailySalesReport>).value;
        expect(report.rows, hasLength(2));
        expect(report.rows.first.date, DateTime(2026, 7));
        expect(report.rows.first.totalSalesInCents, 15000);
        expect(report.rows.first.totalCostInCents, 5000);
        expect(report.rows.first.grossProfitInCents, 10000);
        expect(report.totalSalesInCents, 23000);
        expect(report.totalCostInCents, 7000);
        expect(report.grossProfitInCents, 16000);
      },
    );
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
