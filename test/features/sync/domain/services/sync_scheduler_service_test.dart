import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_settings.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_settings_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';
import 'package:smoo_control/features/sync/domain/services/sync_queue_processor.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';

void main() {
  test('automatic retry honors the existing auto-sync setting', () async {
    final queue = _QueueRepository();
    final scheduler = SyncSchedulerService(
      settingsRepository: const _SettingsRepository(
        SyncSettings(autoSyncEnabled: false),
      ),
      processor: SyncQueueProcessor(
        repository: queue,
        remoteSender: const _Sender(),
      ),
    );

    await scheduler.runAutomaticallyNow();

    expect(queue.pendingCalls, 0);
  });

  test('automatic retry uses the same existing FIFO processor', () async {
    final queue = _QueueRepository();
    final scheduler = SyncSchedulerService(
      settingsRepository: const _SettingsRepository(SyncSettings()),
      processor: SyncQueueProcessor(
        repository: queue,
        remoteSender: const _Sender(),
      ),
    );

    await scheduler.runAutomaticallyNow();

    expect(queue.pendingCalls, 1);
  });

  test(
    'startup starts periodic scheduling and processes queued work',
    () async {
      final queue = _QueueRepository();
      final scheduler = SyncSchedulerService(
        settingsRepository: const _SettingsRepository(SyncSettings()),
        processor: SyncQueueProcessor(
          repository: queue,
          remoteSender: const _Sender(),
        ),
      );

      await scheduler.start();
      await scheduler.start();

      expect(queue.pendingCalls, 1);
      scheduler.dispose();
    },
  );

  test('initialization queue wake respects sync-on-save setting', () async {
    final queue = _QueueRepository();
    final disabled = SyncSchedulerService(
      settingsRepository: const _SettingsRepository(
        SyncSettings(syncOnSave: false),
      ),
      processor: SyncQueueProcessor(
        repository: queue,
        remoteSender: const _Sender(),
      ),
    );
    await disabled.runOnSaveNow();
    expect(queue.pendingCalls, 0);

    final enabled = SyncSchedulerService(
      settingsRepository: const _SettingsRepository(SyncSettings()),
      processor: SyncQueueProcessor(
        repository: queue,
        remoteSender: const _Sender(),
      ),
    );
    await enabled.runOnSaveNow();
    expect(queue.pendingCalls, 1);
    disabled.dispose();
    enabled.dispose();
  });

  test('overlapping automatic triggers share one queue run', () async {
    final queue = _QueueRepository();
    final scheduler = SyncSchedulerService(
      settingsRepository: const _SettingsRepository(SyncSettings()),
      processor: SyncQueueProcessor(
        repository: queue,
        remoteSender: const _Sender(),
      ),
    );

    final firstRun = scheduler.runNow();
    final overlappingRun = await scheduler.runNow();
    await firstRun;

    expect(overlappingRun, isNull);
    expect(queue.pendingCalls, 1);
  });
}

final class _SettingsRepository implements ISyncSettingsRepository {
  const _SettingsRepository(this.settings);

  final SyncSettings settings;

  @override
  Future<AppResult<SyncSettings>> getSettings() async => AppSuccess(settings);

  @override
  Future<AppResult<SyncSettings>> saveSettings(SyncSettings settings) async =>
      AppSuccess(settings);
}

final class _QueueRepository implements ISyncQueueRepository {
  int pendingCalls = 0;

  @override
  Future<AppResult<List<SyncQueueItem>>> getPendingItems({
    int limit = 50,
  }) async {
    pendingCalls++;
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<SyncQueueItem>> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, Object?> payload,
    bool syncImmediately = true,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<void>> markError({
    required String itemId,
    required String error,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<void>> markRequiresResolution({
    required String itemId,
    required String reason,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<void>> markSynced(String itemId) =>
      throw UnimplementedError();

  @override
  Future<AppResult<void>> markSyncing(String itemId) =>
      throw UnimplementedError();
}

final class _Sender implements ISyncRemoteSender {
  const _Sender();

  @override
  Future<void> push(SyncQueueItem item) async {}
}
