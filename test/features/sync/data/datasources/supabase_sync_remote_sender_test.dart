import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/sync/data/datasources/supabase_sync_remote_sender.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

void main() {
  group('SupabaseSyncRemoteSender', () {
    test('moves product category children before remote delete', () async {
      final requests = <http.Request>[];
      final sender = SupabaseSyncRemoteSender(
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
          authEmail: 'tablet@smoo.test',
          authPassword: 'secret',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/auth/v1/token') {
            return _jsonResponse({
              'access_token': 'token',
              'expires_in': 3600,
              'user': {'id': 'remote-user'},
            });
          }
          return http.Response('', 204);
        }),
      );

      await sender.push(
        SyncQueueItem(
          id: 'queue-1',
          entityType: 'product_categories',
          entityId: 'category-child',
          operation: SyncOperation.delete,
          payload: const {
            'id': 'category-child',
            'parentId': 'category-root',
          },
          status: SyncQueueStatus.pending,
          retryCount: 0,
          createdAt: DateTime(2026, 6, 30),
          updatedAt: DateTime(2026, 6, 30),
        ),
      );

      final dataRequests = requests
          .where((request) => request.url.path.startsWith('/rest/v1/'))
          .toList();
      expect(dataRequests.map((request) => request.method), [
        'PATCH',
        'PATCH',
        'DELETE',
      ]);
      expect(dataRequests[0].url.path, '/rest/v1/product_categories');
      expect(
        dataRequests[0].url.queryParameters['parent_id'],
        'eq.category-child',
      );
      final categoryPatchBody =
          jsonDecode(dataRequests[0].body) as Map<String, Object?>;
      expect(categoryPatchBody['parent_id'], 'category-root');
      expect(dataRequests[1].url.path, '/rest/v1/products');
      expect(
        dataRequests[1].url.queryParameters['category_id'],
        'eq.category-child',
      );
      final productPatchBody =
          jsonDecode(dataRequests[1].body) as Map<String, Object?>;
      expect(productPatchBody['category_id'], 'category-root');
      expect(dataRequests[2].url.path, '/rest/v1/product_categories');
      expect(dataRequests[2].url.queryParameters['id'], 'eq.category-child');
    });

    test('pushes inventory movements through the idempotent RPC', () async {
      final requests = <http.Request>[];
      final sender = SupabaseSyncRemoteSender(
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
          authEmail: 'tablet@smoo.test',
          authPassword: 'secret',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: '11111111-1111-1111-1111-111111111111',
        ),
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/auth/v1/token') {
            return _jsonResponse({
              'access_token': 'token',
              'expires_in': 3600,
              'user': {'id': 'remote-user'},
            });
          }
          return http.Response('', 204);
        }),
      );

      await sender.push(
        SyncQueueItem(
          id: 'queue-inventory',
          entityType: 'inventory_movements',
          entityId: 'movement-1',
          operation: SyncOperation.create,
          payload: const {
            'id': 'movement-1',
            'productId': '22222222-2222-2222-2222-222222222222',
            'movementType': 'sale',
            'quantityDelta': -2,
            'referenceType': 'sale',
            'referenceId': 'sale-1',
            'userId': 'user-1',
            'notes': null,
            'createdAt': '2026-06-30T10:00:00.000',
          },
          status: SyncQueueStatus.pending,
          retryCount: 0,
          createdAt: DateTime(2026, 6, 30),
          updatedAt: DateTime(2026, 6, 30),
        ),
      );

      final rpcRequest = requests.singleWhere(
        (request) =>
            request.url.path == '/rest/v1/rpc/apply_inventory_movement',
      );
      final body = jsonDecode(rpcRequest.body) as Map<String, Object?>;

      expect(rpcRequest.method, 'POST');
      expect(body['p_id'], 'movement-1');
      expect(body['p_quantity_delta'], -2);
      expect(body['p_movement_type'], 'sale');
    });
  });
}

http.Response _jsonResponse(Object value) {
  return http.Response(
    jsonEncode(value),
    200,
    headers: const {'content-type': 'application/json'},
  );
}
