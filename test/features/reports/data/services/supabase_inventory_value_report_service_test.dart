import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/data/services/supabase_inventory_value_report_service.dart';
import 'package:smoo_control/features/reports/domain/entities/inventory_value_report.dart';

void main() {
  group('SupabaseInventoryValueReportService', () {
    test('calculates current inventory cost and potential profit', () async {
      final session = CurrentRemoteSessionService()
        ..set(
          accessToken: 'remote-token',
          userId: 'admin-user',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
      final service = SupabaseInventoryValueReportService(
        client: _FakeClient((request) async {
          expect(request.headers['authorization'], 'Bearer remote-token');
          if (request.url.path.endsWith('/products')) {
            expect(request.url.queryParameters['tracks_inventory'], 'eq.true');
            return http.Response(
              jsonEncode([
                {
                  'id': 'product-1',
                  'name': 'Pepsi',
                  'category_id': 'subcategory-1',
                  'cost': 10,
                  'price': 25,
                  'is_raw_material': false,
                },
                {
                  'id': 'product-2',
                  'name': 'Azucar',
                  'category_id': 'subcategory-1',
                  'cost': 8,
                  'price': 0,
                  'is_raw_material': true,
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.url.path.endsWith('/product_categories')) {
            return http.Response(
              jsonEncode([
                {'id': 'category-1', 'parent_id': null, 'name': 'Bebidas'},
                {
                  'id': 'subcategory-1',
                  'parent_id': 'category-1',
                  'name': 'Gaseosas',
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.url.path.endsWith('/inventory_stock')) {
            return http.Response(
              jsonEncode([
                {'product_id': 'product-1', 'quantity_on_hand': 10},
                {'product_id': 'product-2', 'quantity_on_hand': 5},
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

      final result = await service.load();

      expect(result, isA<AppSuccess<InventoryValueReport>>());
      final report = (result as AppSuccess<InventoryValueReport>).value;
      expect(report.rows, hasLength(2));
      expect(report.inventoryCostInCents, 14000);
      expect(report.potentialSalesInCents, 25000);
      expect(report.potentialGrossProfitInCents, 15000);
      expect(report.missingPriceCount, 0);
      expect(report.byCategory.single.categoryName, 'Bebidas / Gaseosas');
      expect(report.byCategory.single.productCount, 2);
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
