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
  test('blocks a legacy sale before any non-atomic REST write', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final requests = <http.Request>[];
    final session = CurrentRemoteSessionService()
      ..set(accessToken: 'local-test-token', userId: 'local-test-user');
    final sender = SupabaseSyncRemoteSender(
      database: database,
      config: const SupabaseAppConfig(
        supabaseUrl: 'https://local.test',
        publishableKey: 'local-test-key',
      ),
      restaurantService: const CurrentRestaurantService(
        restaurantId: '11111111-1111-4111-8111-111111111111',
      ),
      remoteSessionService: session,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );

    await expectLater(
      sender.push(
        SyncQueueItem(
          id: 'legacy-sale-queue',
          entityType: 'sales',
          entityId: '22222222-2222-4222-8222-222222222222',
          operation: SyncOperation.create,
          payload: const {
            'sale': {
              'id': '22222222-2222-4222-8222-222222222222',
              'totalInCents': 100,
              'createdAt': '2026-11-19T12:00:00Z',
            },
            'items': [],
          },
          status: SyncQueueStatus.pending,
          retryCount: 0,
          createdAt: DateTime(2026, 11, 19),
          updatedAt: DateTime(2026, 11, 19),
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'pos_sale_requires_device_sync',
        ),
      ),
    );

    expect(requests, isEmpty);
    session.dispose();
  });
}
