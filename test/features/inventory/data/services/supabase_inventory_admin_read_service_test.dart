import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/inventory/data/services/supabase_inventory_admin_read_service.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_stock_item.dart';

void main() {
  test(
    'loads tracked product and packaging items from one canonical source',
    () async {
      final paths = <String>[];
      final service = SupabaseInventoryAdminReadService(
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
        remoteSessionService: CurrentRemoteSessionService()
          ..set(
            accessToken: 'token',
            userId: 'admin-user',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/items')) {
            expect(request.url.queryParameters['tracks_inventory'], 'eq.true');
            return _json([
              {
                'id': 'sale-item',
                'name': 'Café',
                'item_class': 'sale_product',
                'base_unit_cost': 3,
              },
              {
                'id': 'packaging-item',
                'name': 'Caja',
                'item_class': 'packaging',
                'base_unit_cost': 1,
              },
            ]);
          }
          if (request.url.path.endsWith('/measurement_units') ||
              request.url.path.endsWith('/product_categories')) {
            return _json([]);
          }
          if (request.url.path.endsWith('/inventory_stock')) {
            return _json([
              {'item_id': 'sale-item', 'quantity_on_hand': 8},
              {'item_id': 'packaging-item', 'quantity_on_hand': 17},
            ]);
          }
          fail('Unexpected inventory source ${request.url.path}');
        }),
      );

      final result = await service.getTrackedProductStock();

      expect(result, isA<AppSuccess<List<InventoryStockItem>>>());
      final rows = (result as AppSuccess<List<InventoryStockItem>>).value;
      expect(rows, hasLength(2));
      final packaging = rows.singleWhere(
        (item) => item.itemClass == 'packaging',
      );
      expect(packaging.productId, 'packaging-item');
      expect(packaging.productName, 'Caja');
      expect(packaging.quantityOnHand, 17);
      expect(paths, isNot(contains('/rest/v1/packaging_items')));
      expect(paths, isNot(contains('/rest/v1/packaging_stock')));
      expect(paths, contains('/rest/v1/items'));
      expect(paths, contains('/rest/v1/inventory_stock'));
    },
  );
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);
