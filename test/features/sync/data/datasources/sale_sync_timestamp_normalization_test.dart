import 'dart:convert';

import 'package:drift/drift.dart';
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
  test('normalizes legacy local sale timestamps before RPC', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final eventTime = DateTime(2026, 11, 20, 15, 11, 9);
    await database
        .into(database.localDeviceState)
        .insert(
          LocalDeviceStateCompanion.insert(
            deviceId: '33333333-3333-4333-8333-333333333333',
            restaurantId: '11111111-1111-4111-8111-111111111111',
            initializedByUserId: '44444444-4444-4444-8444-444444444444',
            initializedAt: eventTime,
            lastFullRestoreAt: eventTime,
            lastRestoreStatus: 'completed',
            syncDeviceId: const Value('33333333-3333-4333-8333-333333333333'),
            syncDeviceSecret: const Value('device-secret'),
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
        return http.Response(jsonEncode({'invoice_number': 'F-1'}), 200);
      }),
    );

    await sender.push(
      SyncQueueItem(
        id: 'queue-time-test',
        entityType: 'sales',
        entityId: '66666666-6666-4666-8666-666666666666',
        operation: SyncOperation.create,
        payload: {
          'sale': {
            'id': '66666666-6666-4666-8666-666666666666',
            'invoiceNumber': 'F-1',
            'paymentMethodId': '77777777-7777-4777-8777-777777777777',
            'cashierId': '44444444-4444-4444-8444-444444444444',
            'businessDate': '2026-11-20',
            'status': 'completed',
            'totalInCents': 18000,
            'createdAt': eventTime.toIso8601String(),
          },
          'items': [
            {
              'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              'productId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
              'productName': 'Pollo',
              'quantity': 1,
              'unitPriceInCents': 18000,
              'unitCostInCents': 0,
              'createdAt': eventTime.toIso8601String(),
            },
          ],
          'inventoryMovements': const <Object?>[],
          'packagingMovements': const <Object?>[],
        },
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: eventTime,
        updatedAt: eventTime,
      ),
    );

    final rpcRequest = requests.single;
    final body = jsonDecode(rpcRequest.body) as Map<String, Object?>;
    final payload = body['p_payload']! as Map<String, Object?>;
    final sale = payload['sale']! as Map<String, Object?>;
    final line = (payload['items']! as List).single as Map<String, Object?>;
    final expectedUtc = eventTime.toUtc().toIso8601String();
    expect(sale['sold_at'], expectedUtc);
    expect(line['created_at'], expectedUtc);
    expect(sale['sold_at'], endsWith('Z'));
  });
}
