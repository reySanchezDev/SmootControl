import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

void main() {
  group('SyncQueueRepository', () {
    late AppDatabase database;
    late SyncQueueRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('enqueues and returns pending local operations', () async {
      final enqueueResult = await repository.enqueue(
        entityType: 'sale',
        entityId: 'sale-1',
        operation: SyncOperation.create,
        payload: const {'total': 1200},
      );
      final pendingResult = await repository.getPendingItems();

      expect(enqueueResult, isA<AppSuccess<SyncQueueItem>>());
      expect(pendingResult, isA<AppSuccess<List<SyncQueueItem>>>());

      final pending = (pendingResult as AppSuccess<List<SyncQueueItem>>).value;
      expect(pending, hasLength(1));
      expect(pending.single.entityType, 'sale');
      expect(pending.single.payload, {'total': 1200});
      expect(pending.single.status, SyncQueueStatus.pending);
    });

    test('updates queue item status locally', () async {
      final enqueueResult = await repository.enqueue(
        entityType: 'expense',
        entityId: 'expense-1',
        operation: SyncOperation.update,
        payload: const {'amount': 500},
      );
      final item = (enqueueResult as AppSuccess<SyncQueueItem>).value;

      await repository.markSyncing(item.id);
      var rows = await database.select(database.localSyncQueue).get();
      expect(rows.single.status, SyncQueueStatus.syncing.name);

      await repository.markError(itemId: item.id, error: 'Sin conexion');
      rows = await database.select(database.localSyncQueue).get();
      expect(rows.single.status, SyncQueueStatus.error.name);
      expect(rows.single.retryCount, 1);
      expect(rows.single.lastError, 'Sin conexion');

      await repository.markSynced(item.id);
      rows = await database.select(database.localSyncQueue).get();
      expect(rows.single.status, SyncQueueStatus.synced.name);
      expect(rows.single.lastError, isNull);
    });
  });
}
