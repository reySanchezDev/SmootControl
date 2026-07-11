import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_settings.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_settings_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

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

    test('keeps access-control rows pending for remote sync', () async {
      final enqueueResult = await repository.enqueue(
        entityType: 'profiles',
        entityId: 'user-admin',
        operation: SyncOperation.create,
        payload: const {'email': 'admin@smoo.test'},
      );
      final newItem = (enqueueResult as AppSuccess<SyncQueueItem>).value;
      expect(newItem.status, SyncQueueStatus.pending);
      expect(
        await database.select(database.localSyncQueue).get(),
        hasLength(1),
      );

      final now = DateTime(2026, 6, 30, 20, 9);
      await database
          .into(database.localSyncQueue)
          .insert(
            LocalSyncQueueCompanion.insert(
              id: 'old-profile',
              entityType: 'profiles',
              entityId: 'user-waiter',
              operation: SyncOperation.update.name,
              payloadJson: '{}',
              status: Value(SyncQueueStatus.error.name),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final pendingResult = await repository.getPendingItems();
      final pending = (pendingResult as AppSuccess<List<SyncQueueItem>>).value;
      final rows = await database.select(database.localSyncQueue).get();

      expect(
        pending.map((item) => item.entityId),
        containsAll([
          'user-admin',
          'user-waiter',
        ]),
      );
      expect(
        rows.map((item) => item.status),
        containsAll([
          SyncQueueStatus.pending.name,
          SyncQueueStatus.error.name,
        ]),
      );
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

    test('syncs immediately when a remote sender is configured', () async {
      final sender = _RecordingSender();
      repository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
        remoteSender: sender,
      );

      final enqueueResult = await repository.enqueue(
        entityType: 'product',
        entityId: 'product-1',
        operation: SyncOperation.create,
        payload: const {'name': 'Cafe'},
      );
      final item = (enqueueResult as AppSuccess<SyncQueueItem>).value;
      await _waitForQueueStatus(database, item.id, SyncQueueStatus.synced);
      final pendingResult = await repository.getPendingItems();

      expect(sender.pushed.map((item) => item.entityId), ['product-1']);
      expect(
        (pendingResult as AppSuccess<List<SyncQueueItem>>).value,
        isEmpty,
      );

      final rows = await database.select(database.localSyncQueue).get();
      expect(rows.single.status, SyncQueueStatus.synced.name);
      expect(rows.single.lastError, isNull);
    });

    test(
      'syncs on save even when periodic automatic sync is disabled',
      () async {
        final sender = _RecordingSender();
        repository = SyncQueueRepository(
          LocalSyncQueueDataSource(database),
          remoteSender: sender,
          settingsRepository: const _SettingsRepositoryFake(
            SyncSettings(
              autoSyncEnabled: false,
            ),
          ),
        );

        await repository.enqueue(
          entityType: 'sales',
          entityId: 'sale-1',
          operation: SyncOperation.create,
          payload: const {'id': 'sale-1'},
        );

        await _waitForQueueStatus(
          database,
          (await database.select(database.localSyncQueue).get()).single.id,
          SyncQueueStatus.synced,
        );
        expect(sender.pushed.map((item) => item.entityId), ['sale-1']);
        final pendingResult = await repository.getPendingItems();
        expect(
          (pendingResult as AppSuccess<List<SyncQueueItem>>).value,
          isEmpty,
        );
      },
    );

    test('keeps failed immediate syncs eligible for retry', () async {
      repository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
        remoteSender: const _FailingSender(),
      );

      final enqueueResult = await repository.enqueue(
        entityType: 'product',
        entityId: 'product-1',
        operation: SyncOperation.create,
        payload: const {'name': 'Cafe'},
      );
      final item = (enqueueResult as AppSuccess<SyncQueueItem>).value;
      await _waitForQueueStatus(database, item.id, SyncQueueStatus.error);
      final pendingResult = await repository.getPendingItems();

      final pending = (pendingResult as AppSuccess<List<SyncQueueItem>>).value;
      expect(pending, hasLength(1));
      expect(pending.single.status, SyncQueueStatus.error);
      expect(pending.single.lastError, contains('Sin conexion'));
    });

    test('marks timed out immediate syncs as retryable errors', () async {
      final sender = _BlockingSender();
      repository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
        remoteSender: sender,
        immediateSyncTimeout: const Duration(milliseconds: 20),
      );

      final enqueueResult = await repository.enqueue(
        entityType: 'sales',
        entityId: 'sale-timeout',
        operation: SyncOperation.create,
        payload: const {'id': 'sale-timeout'},
      );
      final item = (enqueueResult as AppSuccess<SyncQueueItem>).value;

      await _waitForQueueStatus(database, item.id, SyncQueueStatus.error);
      sender.complete();

      final pendingResult = await repository.getPendingItems();
      final pending = (pendingResult as AppSuccess<List<SyncQueueItem>>).value;
      expect(pending.single.id, item.id);
      expect(pending.single.retryCount, 1);
    });

    test(
      'retries stale syncing items but ignores fresh syncing items',
      () async {
        final enqueueResult = await repository.enqueue(
          entityType: 'sales',
          entityId: 'sale-stale',
          operation: SyncOperation.create,
          payload: const {'id': 'sale-stale'},
        );
        final item = (enqueueResult as AppSuccess<SyncQueueItem>).value;
        await repository.markSyncing(item.id);

        var pendingResult = await repository.getPendingItems();
        expect(
          (pendingResult as AppSuccess<List<SyncQueueItem>>).value,
          isEmpty,
        );

        await (database.update(
          database.localSyncQueue,
        )..where((row) => row.id.equals(item.id))).write(
          LocalSyncQueueCompanion(
            updatedAt: Value(
              DateTime.now().subtract(const Duration(minutes: 3)),
            ),
          ),
        );

        pendingResult = await repository.getPendingItems();
        final pending =
            (pendingResult as AppSuccess<List<SyncQueueItem>>).value;
        expect(pending.single.id, item.id);
        expect(pending.single.status, SyncQueueStatus.syncing);
      },
    );

    test(
      'does not block local enqueue while immediate sync is pending',
      () async {
        final sender = _BlockingSender();
        repository = SyncQueueRepository(
          LocalSyncQueueDataSource(database),
          remoteSender: sender,
        );

        final enqueueResult = await repository
            .enqueue(
              entityType: 'sales',
              entityId: 'sale-1',
              operation: SyncOperation.create,
              payload: const {'id': 'sale-1'},
            )
            .timeout(const Duration(seconds: 1));
        final item = (enqueueResult as AppSuccess<SyncQueueItem>).value;

        await sender.pushStarted.future.timeout(const Duration(seconds: 1));
        expect(sender.pushed.map((item) => item.entityId), ['sale-1']);

        final rows = await database.select(database.localSyncQueue).get();
        expect(rows.single.id, item.id);
        expect(rows.single.status, SyncQueueStatus.syncing.name);

        sender.complete();
        await _waitForQueueStatus(database, item.id, SyncQueueStatus.synced);
      },
    );

    test('serializes immediate sync in queue order', () async {
      final sender = _BlockingSender();
      repository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
        remoteSender: sender,
      );

      final firstResult = await repository.enqueue(
        entityType: 'sales',
        entityId: 'sale-1',
        operation: SyncOperation.create,
        payload: const {'id': 'sale-1'},
      );
      final first = (firstResult as AppSuccess<SyncQueueItem>).value;
      await sender.pushStarted.future.timeout(const Duration(seconds: 1));

      final secondResult = await repository.enqueue(
        entityType: 'sales',
        entityId: 'sale-2',
        operation: SyncOperation.create,
        payload: const {'id': 'sale-2'},
      );
      final second = (secondResult as AppSuccess<SyncQueueItem>).value;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(sender.pushed.map((item) => item.entityId), ['sale-1']);

      sender.complete();
      await _waitForQueueStatus(database, first.id, SyncQueueStatus.synced);
      await _waitForQueueStatus(database, second.id, SyncQueueStatus.synced);
      expect(sender.pushed.map((item) => item.entityId), ['sale-1', 'sale-2']);
    });

    test('does not bypass an older failed queue item', () async {
      final sender = _FailFirstSender();
      repository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
        remoteSender: sender,
      );

      final firstResult = await repository.enqueue(
        entityType: 'sales',
        entityId: 'sale-1',
        operation: SyncOperation.create,
        payload: const {'id': 'sale-1'},
      );
      final first = (firstResult as AppSuccess<SyncQueueItem>).value;
      await _waitForQueueStatus(database, first.id, SyncQueueStatus.error);

      await repository.enqueue(
        entityType: 'sales',
        entityId: 'sale-2',
        operation: SyncOperation.create,
        payload: const {'id': 'sale-2'},
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(sender.pushed.map((item) => item.entityId), ['sale-1']);
      final pending =
          (await repository.getPendingItems()
                  as AppSuccess<List<SyncQueueItem>>)
              .value;
      expect(pending.map((item) => item.entityId), ['sale-1', 'sale-2']);
    });
  });
}

final class _RecordingSender implements ISyncRemoteSender {
  final List<SyncQueueItem> pushed = [];

  @override
  Future<void> push(SyncQueueItem item) async {
    pushed.add(item);
  }
}

final class _FailingSender implements ISyncRemoteSender {
  const _FailingSender();

  @override
  Future<void> push(SyncQueueItem item) {
    throw StateError('Sin conexion');
  }
}

final class _BlockingSender implements ISyncRemoteSender {
  final Completer<void> pushStarted = Completer<void>();
  final Completer<void> _release = Completer<void>();
  final List<SyncQueueItem> pushed = [];

  @override
  Future<void> push(SyncQueueItem item) async {
    pushed.add(item);
    if (!pushStarted.isCompleted) {
      pushStarted.complete();
    }
    await _release.future;
  }

  void complete() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }
}

final class _FailFirstSender implements ISyncRemoteSender {
  final List<SyncQueueItem> pushed = [];

  @override
  Future<void> push(SyncQueueItem item) async {
    pushed.add(item);
    if (pushed.length == 1) {
      throw StateError('Sin conexion');
    }
  }
}

final class _SettingsRepositoryFake implements ISyncSettingsRepository {
  const _SettingsRepositoryFake(this.settings);

  final SyncSettings settings;

  @override
  Future<AppResult<SyncSettings>> getSettings() async {
    return AppSuccess(settings);
  }

  @override
  Future<AppResult<SyncSettings>> saveSettings(SyncSettings settings) async {
    return AppSuccess(settings);
  }
}

Future<void> _waitForQueueStatus(
  AppDatabase database,
  String itemId,
  SyncQueueStatus status,
) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    final row = await (database.select(
      database.localSyncQueue,
    )..where((item) => item.id.equals(itemId))).getSingle();
    if (row.status == status.name) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  final row = await (database.select(
    database.localSyncQueue,
  )..where((item) => item.id.equals(itemId))).getSingle();
  expect(row.status, status.name);
}
