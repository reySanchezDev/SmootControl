import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/inventory/data/services/supabase_inventory_admin_write_service.dart';

void main() {
  group('SupabaseInventoryAdminWriteService', () {
    test('registers product purchases through the batch RPC', () async {
      final requests = <http.Request>[];
      final service = _service(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'item_count': 2}), 200);
        }),
      );

      final result = await service.registerProductPurchaseBatch([
        const AdminInventoryPurchaseItem(
          productId: '11111111-1111-1111-1111-111111111111',
          quantity: 3,
          unitCostInCents: 1250,
        ),
        const AdminInventoryPurchaseItem(
          productId: '22222222-2222-2222-2222-222222222222',
          quantity: 1,
          unitCostInCents: 4000,
        ),
      ]);

      expect(result, isA<AppSuccess<void>>());
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/app_register_inventory_purchase_batch',
      );
      expect(requests.single.headers['authorization'], 'Bearer token');
      final body = jsonDecode(requests.single.body) as Map<String, Object?>;
      expect(body['p_restaurant_id'], 'restaurant-1');
      final items = body['p_items']! as List<Object?>;
      expect(items, hasLength(2));
      expect(
        items.first,
        containsPair('product_id', '11111111-1111-1111-1111-111111111111'),
      );
      expect(items.first, containsPair('quantity', 3));
      expect(items.first, containsPair('unit_cost', 12.5));
      expect(items.first, contains('movement_id'));
    });

    test('registers packaging purchases through the batch RPC', () async {
      final requests = <http.Request>[];
      final service = _service(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'item_count': 1}), 200);
        }),
      );

      final result = await service.registerPackagingPurchaseBatch([
        const AdminPackagingPurchaseItem(
          packagingItemId: '33333333-3333-3333-3333-333333333333',
          quantity: 20,
          unitCostInCents: 150,
        ),
      ]);

      expect(result, isA<AppSuccess<void>>());
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/app_register_packaging_purchase_batch',
      );
      final body = jsonDecode(requests.single.body) as Map<String, Object?>;
      final items = body['p_items']! as List<Object?>;
      expect(
        items.single,
        containsPair(
          'packaging_item_id',
          '33333333-3333-3333-3333-333333333333',
        ),
      );
      expect(items.single, containsPair('quantity', 20));
      expect(items.single, containsPair('unit_cost', 1.5));
    });

    test('registers inventory adjustments through the batch RPC', () async {
      final requests = <http.Request>[];
      final service = _service(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'item_count': 1}), 200);
        }),
      );

      final result = await service.registerInventoryAdjustmentBatch(
        const [
          AdminInventoryAdjustmentItem(
            productId: '44444444-4444-4444-4444-444444444444',
            expectedQuantity: 5,
            countedQuantity: 8,
          ),
        ],
        note: 'Conteo inicial',
      );

      expect(result, isA<AppSuccess<void>>());
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/app_register_inventory_adjustment_batch',
      );
      final body = jsonDecode(requests.single.body) as Map<String, Object?>;
      expect(body['p_note'], 'Conteo inicial');
      final items = body['p_items']! as List<Object?>;
      expect(items.single, contains('movement_id'));
      expect(
        items.single,
        containsPair('product_id', '44444444-4444-4444-4444-444444444444'),
      );
      expect(items.single, containsPair('expected_quantity', 5));
      expect(items.single, containsPair('counted_quantity', 8));
    });

    test('fails before calling Supabase when the batch is empty', () async {
      var called = false;
      final service = _service(
        client: MockClient((request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      final result = await service.registerProductPurchaseBatch(const []);

      expect(result, isA<AppFailureResult<void>>());
      expect(called, isFalse);
    });
  });
}

SupabaseInventoryAdminWriteService _service({required http.Client client}) {
  return SupabaseInventoryAdminWriteService(
    config: const SupabaseAppConfig(
      supabaseUrl: 'https://smoo.test',
      publishableKey: 'publishable-key',
    ),
    restaurantService: const CurrentRestaurantService(
      restaurantId: 'restaurant-1',
    ),
    remoteSessionService: _remoteSession(),
    client: client,
  );
}

CurrentRemoteSessionService _remoteSession() {
  return CurrentRemoteSessionService()..set(
    accessToken: 'token',
    userId: 'admin-user',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}
