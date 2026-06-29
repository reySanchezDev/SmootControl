import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_process_summary.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';
import 'package:smoo_control/features/sync/domain/services/sync_queue_processor.dart';

void main() {
  group('SyncQueueProcessor', () {
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

    test('marks pushed items as synced', () async {
      await _enqueueSale(repository, 'sale-1');
      await _enqueueSale(repository, 'sale-2');
      final processor = SyncQueueProcessor(
        repository: repository,
        remoteSender: const _SuccessfulSender(),
      );

      final result = await processor.processPending();

      expect(
        (result as AppSuccess<SyncProcessSummary>).value,
        const SyncProcessSummary(processed: 2, succeeded: 2, failed: 0),
      );

      final rows = await database.select(database.localSyncQueue).get();
      expect(
        rows.map((row) => row.status),
        everyElement(SyncQueueStatus.synced.name),
      );
    });

    test('processes all successful batches in one run', () async {
      for (var index = 0; index < 55; index++) {
        await _enqueueSale(repository, 'sale-$index');
      }
      final processor = SyncQueueProcessor(
        repository: repository,
        remoteSender: const _SuccessfulSender(),
      );

      final result = await processor.processPending();

      expect(
        (result as AppSuccess<SyncProcessSummary>).value,
        const SyncProcessSummary(processed: 55, succeeded: 55, failed: 0),
      );

      final rows = await database.select(database.localSyncQueue).get();
      expect(
        rows.map((row) => row.status),
        everyElement(SyncQueueStatus.synced.name),
      );
    });

    test('marks failed pushes as error for retry', () async {
      await _enqueueSale(repository, 'sale-1');
      final processor = SyncQueueProcessor(
        repository: repository,
        remoteSender: const _FailingSender(),
      );

      final result = await processor.processPending();

      expect(
        (result as AppSuccess<SyncProcessSummary>).value,
        const SyncProcessSummary(processed: 1, succeeded: 0, failed: 1),
      );

      final rows = await database.select(database.localSyncQueue).get();
      expect(rows.single.status, SyncQueueStatus.error.name);
      expect(rows.single.retryCount, 1);
      expect(rows.single.lastError, contains('Sin conexion'));
    });
  });
}

Future<void> _enqueueSale(
  SyncQueueRepository repository,
  String entityId,
) async {
  await repository.enqueue(
    entityType: 'sale',
    entityId: entityId,
    operation: SyncOperation.create,
    payload: {'id': entityId},
  );
}

final class _SuccessfulSender implements ISyncRemoteSender {
  const _SuccessfulSender();

  @override
  Future<void> push(SyncQueueItem item) async {}
}

final class _FailingSender implements ISyncRemoteSender {
  const _FailingSender();

  @override
  Future<void> push(SyncQueueItem item) {
    throw StateError('Sin conexion');
  }
}
