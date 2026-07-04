import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/sync/data/datasources/supabase_sync_remote_sender.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

void main() {
  group('SupabaseSyncRemoteSender', () {
    test('moves product category children before remote delete', () async {
      final requests = <http.Request>[];
      final sender = SupabaseSyncRemoteSender(
        database: _testDatabase(),
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: 'restaurant-1',
        ),
        remoteSessionService: _remoteSession(),
        client: MockClient((request) async {
          requests.add(request);
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
        database: _testDatabase(),
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: '11111111-1111-1111-1111-111111111111',
        ),
        remoteSessionService: _remoteSession(),
        client: MockClient((request) async {
          requests.add(request);
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

    test('pushes admin access-control writes through RPCs', () async {
      final requests = <http.Request>[];
      final sender = SupabaseSyncRemoteSender(
        database: _testDatabase(),
        config: const SupabaseAppConfig(
          supabaseUrl: 'https://smoo.test',
          publishableKey: 'publishable-key',
        ),
        restaurantService: const CurrentRestaurantService(
          restaurantId: '11111111-1111-4111-8111-111111111111',
        ),
        remoteSessionService: _remoteSession(),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );

      await sender.push(
        SyncQueueItem(
          id: 'queue-role',
          entityType: 'roles',
          entityId: 'role-waiter',
          operation: SyncOperation.create,
          payload: const {
            'id': 'role-waiter',
            'name': 'Mesero',
            'description': 'Atiende mesas',
            'isSystem': true,
            'isActive': true,
          },
          status: SyncQueueStatus.pending,
          retryCount: 0,
          createdAt: DateTime(2026, 7),
          updatedAt: DateTime(2026, 7),
        ),
      );
      await sender.push(
        SyncQueueItem(
          id: 'queue-role-permissions',
          entityType: 'role_permissions',
          entityId: 'role-waiter',
          operation: SyncOperation.update,
          payload: const {
            'roleId': 'role-waiter',
            'permissionCodes': ['sync.ejecutar', 'ventas.registrar'],
          },
          status: SyncQueueStatus.pending,
          retryCount: 0,
          createdAt: DateTime(2026, 7),
          updatedAt: DateTime(2026, 7),
        ),
      );
      await sender.push(
        SyncQueueItem(
          id: 'queue-profile',
          entityType: 'profiles',
          entityId: '22222222-2222-4222-8222-222222222222',
          operation: SyncOperation.create,
          payload: const {
            'id': '22222222-2222-4222-8222-222222222222',
            'displayName': 'Rey',
            'email': 'rey@smoo.test',
            'roleId': 'role-waiter',
            'isPosUser': true,
            'isActive': true,
            'pinSalt': 'salt',
            'pinHash': 'hash',
          },
          status: SyncQueueStatus.pending,
          retryCount: 0,
          createdAt: DateTime(2026, 7),
          updatedAt: DateTime(2026, 7),
        ),
      );

      expect(requests.map((request) => request.url.path), [
        '/rest/v1/rpc/app_upsert_role',
        '/rest/v1/rpc/app_replace_role_permissions',
        '/rest/v1/rpc/app_upsert_profile',
      ]);
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer owner-token',
        ),
        isTrue,
      );

      final roleBody = jsonDecode(requests.first.body) as Map<String, Object?>;
      final rolePayload = roleBody['p_payload']! as Map<String, Object?>;
      expect(
        roleBody['p_restaurant_id'],
        '11111111-1111-4111-8111-111111111111',
      );
      expect(rolePayload['id'], 'role-waiter');
      expect(rolePayload['code'], 'waiter');

      final permissionsBody =
          jsonDecode(requests[1].body) as Map<String, Object?>;
      expect(permissionsBody['p_role_id'], 'role-waiter');
      expect(permissionsBody['p_permission_codes'], [
        'sync.ejecutar',
        'ventas.registrar',
      ]);

      final profileBody =
          jsonDecode(requests.last.body) as Map<String, Object?>;
      final profilePayload = profileBody['p_payload']! as Map<String, Object?>;
      expect(profilePayload['role_id'], 'role-waiter');
      expect(profilePayload['is_pos_user'], isTrue);
    });

    test(
      'uses the current remote admin session when technical auth is absent',
      () async {
        final requests = <http.Request>[];
        final remoteSession = CurrentRemoteSessionService()
          ..set(
            accessToken: 'owner-token',
            userId: 'owner-profile',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          );
        final sender = SupabaseSyncRemoteSender(
          database: _testDatabase(),
          config: const SupabaseAppConfig(
            supabaseUrl: 'https://smoo.test',
            publishableKey: 'publishable-key',
          ),
          restaurantService: const CurrentRestaurantService(
            restaurantId: 'restaurant-1',
          ),
          remoteSessionService: remoteSession,
          client: MockClient((request) async {
            requests.add(request);
            return http.Response('', 204);
          }),
        );

        await sender.push(
          SyncQueueItem(
            id: 'queue-category',
            entityType: 'product_categories',
            entityId: 'category-1',
            operation: SyncOperation.create,
            payload: const {
              'id': 'category-1',
              'parentId': null,
              'name': 'Comidas',
              'sortOrder': 0,
              'isActive': true,
            },
            status: SyncQueueStatus.pending,
            retryCount: 0,
            createdAt: DateTime(2026, 6, 30),
            updatedAt: DateTime(2026, 6, 30),
          ),
        );

        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/rest/v1/product_categories');
        expect(requests.single.headers['authorization'], 'Bearer owner-token');
      },
    );

    test(
      'deletes root leaf payment methods without requiring a parent',
      () async {
        final requests = <http.Request>[];
        final sender = SupabaseSyncRemoteSender(
          database: _testDatabase(),
          config: const SupabaseAppConfig(
            supabaseUrl: 'https://smoo.test',
            publishableKey: 'publishable-key',
          ),
          restaurantService: const CurrentRestaurantService(
            restaurantId: 'restaurant-1',
          ),
          remoteSessionService: _remoteSession(),
          client: MockClient((request) async {
            requests.add(request);
            return http.Response('', 204);
          }),
        );

        await sender.push(
          SyncQueueItem(
            id: 'queue-payment-delete',
            entityType: 'payment_methods',
            entityId: 'payment-root-leaf',
            operation: SyncOperation.delete,
            payload: const {
              'id': 'payment-root-leaf',
              'name': 'Cuenta BANPRO NIO',
              'parentId': null,
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
        expect(dataRequests, hasLength(1));
        expect(dataRequests.single.method, 'DELETE');
        expect(dataRequests.single.url.path, '/rest/v1/payment_methods');
        expect(
          dataRequests.single.url.queryParameters['id'],
          'eq.payment-root-leaf',
        );
      },
    );

    test(
      'pushes cash register sessions with the operational cashier id',
      () async {
        final requests = <http.Request>[];
        final sender = SupabaseSyncRemoteSender(
          database: _testDatabase(),
          config: const SupabaseAppConfig(
            supabaseUrl: 'https://smoo.test',
            publishableKey: 'publishable-key',
          ),
          restaurantService: const CurrentRestaurantService(
            restaurantId: 'restaurant-1',
          ),
          remoteSessionService: _remoteSession(),
          client: MockClient((request) async {
            requests.add(request);
            return http.Response('', 204);
          }),
        );

        await sender.push(
          SyncQueueItem(
            id: 'queue-cash',
            entityType: 'cash_register_sessions',
            entityId: 'cash-session-1',
            operation: SyncOperation.create,
            payload: const {
              'id': 'cash-session-1',
              'cashierId': 'pos-user-1',
              'businessDate': '2026-07-01',
              'openingCashInCents': 50000,
              'physicalClosingCashInCents': null,
              'status': 'open',
            },
            status: SyncQueueStatus.pending,
            retryCount: 0,
            createdAt: DateTime(2026, 7),
            updatedAt: DateTime(2026, 7),
          ),
        );

        final dataRequest = requests.singleWhere(
          (request) => request.url.path == '/rest/v1/cash_register_sessions',
        );
        final body = jsonDecode(dataRequest.body) as Map<String, Object?>;
        expect(body['cashier_user_id'], 'pos-user-1');
      },
    );

    test(
      'pushes POS cash and sales through device RPC without admin session',
      () async {
        final database = _testDatabase();
        final now = DateTime(2026, 7);
        await database
            .into(database.localDeviceState)
            .insert(
              LocalDeviceStateCompanion.insert(
                deviceId: '33333333-3333-4333-8333-333333333333',
                restaurantId: '11111111-1111-4111-8111-111111111111',
                initializedByUserId: '44444444-4444-4444-8444-444444444444',
                initializedAt: now,
                lastFullRestoreAt: now,
                lastRestoreStatus: 'completed',
                syncDeviceId: const Value(
                  '33333333-3333-4333-8333-333333333333',
                ),
                syncDeviceSecret: const Value('device-secret'),
              ),
            );
        await database
            .into(database.localBusinessSettings)
            .insert(
              LocalBusinessSettingsCompanion(
                id: const Value('default'),
                businessName: const Value('Smoo Test'),
                invoicePrefix: const Value('F-'),
                initialInvoiceNumber: const Value(1),
                nextInvoiceNumber: const Value(6),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await database
            .into(database.localSales)
            .insert(
              LocalSalesCompanion(
                id: const Value('66666666-6666-4666-8666-666666666666'),
                invoiceNumber: const Value('F-6'),
                paymentMethodId: const Value(
                  '77777777-7777-4777-8777-777777777777',
                ),
                status: const Value('completed'),
                subtotalInCents: const Value(18000),
                totalInCents: const Value(18000),
                syncStatus: const Value('pending'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        final requests = <http.Request>[];
        final sender = SupabaseSyncRemoteSender(
          database: database,
          config: const SupabaseAppConfig(
            supabaseUrl: 'https://smoo.test',
            publishableKey: 'publishable-key',
          ),
          restaurantService: const CurrentRestaurantService(
            restaurantId: '11111111-1111-4111-8111-111111111111',
          ),
          remoteSessionService: CurrentRemoteSessionService(),
          client: MockClient((request) async {
            requests.add(request);
            if (request.url.path ==
                '/rest/v1/rpc/pos_sync_cash_register_session') {
              return http.Response(
                jsonEncode({
                  'remote_id': '55555555-5555-4555-8555-555555555555',
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'remote_id': '66666666-6666-4666-8666-666666666666',
                'invoice_number': 'F-7',
                'original_invoice_number': 'F-6',
                'renumbered_invoice': true,
              }),
              200,
            );
          }),
        );

        await sender.push(
          SyncQueueItem(
            id: 'queue-cash-device',
            entityType: 'cash_register_sessions',
            entityId: '55555555-5555-4555-8555-555555555555',
            operation: SyncOperation.create,
            payload: const {
              'id': '55555555-5555-4555-8555-555555555555',
              'cashierId': '44444444-4444-4444-8444-444444444444',
              'businessDate': '2026-07-01',
              'openingCashInCents': 50000,
              'physicalClosingCashInCents': null,
              'status': 'open',
            },
            status: SyncQueueStatus.pending,
            retryCount: 0,
            createdAt: DateTime(2026, 7),
            updatedAt: DateTime(2026, 7),
          ),
        );

        await sender.push(
          SyncQueueItem(
            id: 'queue-sale-device',
            entityType: 'sales',
            entityId: '66666666-6666-4666-8666-666666666666',
            operation: SyncOperation.create,
            payload: const {
              'sale': {
                'id': '66666666-6666-4666-8666-666666666666',
                'invoiceNumber': 'F-1',
                'tableId': null,
                'tableAccountId': null,
                'paymentMethodId': '77777777-7777-4777-8777-777777777777',
                'salesTypeId': null,
                'salesTypeName': null,
                'paymentReference': null,
                'cashRegisterSessionId': '55555555-5555-4555-8555-555555555555',
                'cashierId': '44444444-4444-4444-8444-444444444444',
                'businessDate': '2026-07-01',
                'status': 'completed',
                'totalInCents': 18000,
                'createdAt': '2026-07-01T14:03:00.000',
              },
              'items': [],
              'inventoryMovements': [],
              'packagingMovements': [],
            },
            status: SyncQueueStatus.pending,
            retryCount: 0,
            createdAt: DateTime(2026, 7),
            updatedAt: DateTime(2026, 7),
          ),
        );

        expect(requests.map((request) => request.url.path), [
          '/rest/v1/rpc/pos_sync_cash_register_session',
          '/rest/v1/rpc/pos_sync_sale',
        ]);
        expect(
          requests.every((request) {
            return !request.headers.containsKey('authorization');
          }),
          isTrue,
        );

        final saleBody = jsonDecode(requests.last.body) as Map<String, Object?>;
        final payload = saleBody['p_payload']! as Map<String, Object?>;
        final sale = payload['sale']! as Map<String, Object?>;
        expect(
          sale['cash_register_session_id'],
          '55555555-5555-4555-8555-555555555555',
        );
        final localSale = await database
            .select(database.localSales)
            .getSingle();
        expect(localSale.invoiceNumber, 'F-7');
        expect(localSale.syncStatus, 'synced');

        final settings = await database
            .select(database.localBusinessSettings)
            .getSingle();
        expect(settings.nextInvoiceNumber, 8);
      },
    );

    test(
      'reuses existing remote open cash session when local cash collides',
      () async {
        final requests = <http.Request>[];
        final sender = SupabaseSyncRemoteSender(
          database: _testDatabase(),
          config: const SupabaseAppConfig(
            supabaseUrl: 'https://smoo.test',
            publishableKey: 'publishable-key',
          ),
          restaurantService: const CurrentRestaurantService(
            restaurantId: 'restaurant-1',
          ),
          remoteSessionService: _remoteSession(),
          client: MockClient((request) async {
            requests.add(request);
            if (request.method == 'POST' &&
                request.url.path == '/rest/v1/cash_register_sessions') {
              return http.Response(
                jsonEncode({
                  'code': '23505',
                  'message':
                      'duplicate key value violates unique constraint '
                      '"cash_register_one_open_per_user_day_idx"',
                }),
                409,
              );
            }
            if (request.method == 'GET' &&
                request.url.path == '/rest/v1/cash_register_sessions') {
              return http.Response(
                jsonEncode([
                  {'id': 'cash-remote-open'},
                ]),
                200,
              );
            }
            return http.Response('', 204);
          }),
        );

        await sender.push(
          SyncQueueItem(
            id: 'queue-cash',
            entityType: 'cash_register_sessions',
            entityId: 'cash-local',
            operation: SyncOperation.create,
            payload: const {
              'id': 'cash-local',
              'cashierId': 'pos-user-1',
              'businessDate': '2026-07-01',
              'openingCashInCents': 50000,
              'physicalClosingCashInCents': null,
              'status': 'open',
            },
            status: SyncQueueStatus.pending,
            retryCount: 0,
            createdAt: DateTime(2026, 7),
            updatedAt: DateTime(2026, 7),
          ),
        );

        await sender.push(
          SyncQueueItem(
            id: 'queue-sale',
            entityType: 'sales',
            entityId: 'sale-local',
            operation: SyncOperation.create,
            payload: const {
              'sale': {
                'id': 'sale-local',
                'invoiceNumber': 'F-1',
                'tableId': null,
                'tableAccountId': null,
                'paymentMethodId': 'payment-cash',
                'salesTypeId': null,
                'salesTypeName': null,
                'paymentReference': null,
                'cashRegisterSessionId': 'cash-local',
                'cashierId': 'pos-user-1',
                'businessDate': '2026-07-01',
                'status': 'completed',
                'subtotalInCents': 18000,
                'totalInCents': 18000,
                'createdAt': '2026-07-01T14:03:00.000',
              },
              'items': [],
              'inventoryMovements': [],
              'packagingMovements': [],
            },
            status: SyncQueueStatus.pending,
            retryCount: 0,
            createdAt: DateTime(2026, 7),
            updatedAt: DateTime(2026, 7),
          ),
        );

        final saleRequest = requests.singleWhere(
          (request) => request.url.path == '/rest/v1/sales',
        );
        final saleBody = jsonDecode(saleRequest.body) as Map<String, Object?>;
        expect(saleBody['cash_register_session_id'], 'cash-remote-open');
      },
    );
  });
}

CurrentRemoteSessionService _remoteSession() {
  return CurrentRemoteSessionService()..set(
    accessToken: 'owner-token',
    userId: 'owner-profile',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}

AppDatabase _testDatabase() {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  return database;
}
