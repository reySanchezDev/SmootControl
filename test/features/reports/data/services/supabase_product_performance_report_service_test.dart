import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/data/services/supabase_product_performance_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/product_performance_report.dart';

void main() {
  test('groups products by quantity and gross profit', () async {
    final session = CurrentRemoteSessionService()
      ..set(
        accessToken: 'remote-token',
        userId: 'admin-user',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    final service = SupabaseProductPerformanceReportService(
      client: _FakeClient((request) async {
        expect(request.headers['authorization'], 'Bearer remote-token');
        expect(
          request.url.path,
          endsWith('/rpc/app_get_product_performance_report'),
        );
        if (request is http.Request) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['p_restaurant_id'], 'restaurant-1');
          expect(body['p_from'], '2026-05-01');
          expect(body['p_to'], '2026-07-15');
          return http.Response(
            jsonEncode([
              {
                'product_id': 'burger',
                'product_name': 'Hamburguesa',
                'category_name': 'Fast food',
                'quantity_sold': 10,
                'sales_amount': 1000,
                'cost_amount': 800,
                'gross_profit_amount': 200,
              },
              {
                'product_id': 'tajadas',
                'product_name': 'Tajadas con queso',
                'category_name': 'Extras',
                'quantity_sold': 3,
                'sales_amount': 180,
                'cost_amount': 30,
                'gross_profit_amount': 150,
              },
            ]),
            200,
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
      from: DateTime(2026, 5),
      to: DateTime(2026, 7, 15),
    );

    expect(result, isA<AppSuccess<ProductPerformanceReport>>());
    final report = (result as AppSuccess<ProductPerformanceReport>).value;
    expect(report.rows, hasLength(2));
    expect(report.bestSeller?.productName, 'Hamburguesa');
    expect(report.mostProfitable?.productName, 'Hamburguesa');
    expect(report.bestMargin?.productName, 'Tajadas con queso');
    expect(report.totalSalesInCents, 118000);
    expect(report.totalCostInCents, 83000);
    expect(report.grossProfitInCents, 35000);
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
      request: request,
    );
  }
}
