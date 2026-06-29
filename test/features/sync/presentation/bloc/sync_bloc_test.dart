import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_settings.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_settings_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';
import 'package:smoo_control/features/sync/domain/services/sync_queue_processor.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_event.dart';
import 'package:smoo_control/features/sync/presentation/bloc/sync_state.dart';

void main() {
  group('SyncBloc', () {
    final item = _syncItem();

    blocTest<SyncBloc, SyncState>(
      'loads pending queue items',
      build: () {
        final repository = _SyncQueueRepositoryFake(items: [item]);
        final settingsRepository = _SyncSettingsRepositoryFake();
        final processor = SyncQueueProcessor(
          repository: repository,
          remoteSender: const _SuccessfulRemoteSenderFake(),
        );

        return SyncBloc(
          repository: repository,
          settingsRepository: settingsRepository,
          processor: processor,
          scheduler: SyncSchedulerService(
            settingsRepository: settingsRepository,
            processor: processor,
          ),
        );
      },
      act: (bloc) => bloc.add(const SyncQueueRequested()),
      expect: () => [
        const SyncLoading(),
        SyncLoaded(items: [item], settings: const SyncSettings()),
      ],
    );

    blocTest<SyncBloc, SyncState>(
      'processes pending queue items',
      build: () {
        final repository = _SyncQueueRepositoryFake(items: [item]);
        final settingsRepository = _SyncSettingsRepositoryFake();
        final processor = SyncQueueProcessor(
          repository: repository,
          remoteSender: const _SuccessfulRemoteSenderFake(),
        );

        return SyncBloc(
          repository: repository,
          settingsRepository: settingsRepository,
          processor: processor,
          scheduler: SyncSchedulerService(
            settingsRepository: settingsRepository,
            processor: processor,
          ),
        );
      },
      act: (bloc) => bloc.add(const SyncProcessRequested()),
      expect: () => [
        const SyncLoading(),
        isA<SyncLoaded>()
            .having((state) => state.items, 'items', isEmpty)
            .having((state) => state.lastSummary?.processed, 'processed', 1)
            .having((state) => state.lastSummary?.succeeded, 'succeeded', 1)
            .having((state) => state.lastSummary?.failed, 'failed', 0),
      ],
    );
  });
}

SyncQueueItem _syncItem() {
  final now = DateTime(2026, 1, 1, 8);

  return SyncQueueItem(
    id: 'queue-1',
    entityType: 'sales',
    entityId: 'sale-1',
    operation: SyncOperation.create,
    payload: const {'id': 'sale-1'},
    status: SyncQueueStatus.pending,
    retryCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

final class _SyncQueueRepositoryFake implements ISyncQueueRepository {
  _SyncQueueRepositoryFake({required List<SyncQueueItem> items})
    : _items = [...items];

  final List<SyncQueueItem> _items;

  @override
  Future<AppResult<SyncQueueItem>> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, Object?> payload,
  }) async {
    final item = _syncItem();
    _items.add(item);

    return AppSuccess(item);
  }

  @override
  Future<AppResult<List<SyncQueueItem>>> getPendingItems({
    int limit = 50,
  }) async {
    final pending = _items
        .where(
          (item) =>
              item.status == SyncQueueStatus.pending ||
              item.status == SyncQueueStatus.error,
        )
        .take(limit)
        .toList();

    return AppSuccess(pending);
  }

  @override
  Future<AppResult<void>> markError({
    required String itemId,
    required String error,
  }) async {
    _replaceStatus(itemId, SyncQueueStatus.error, lastError: error);

    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<void>> markSynced(String itemId) async {
    _replaceStatus(itemId, SyncQueueStatus.synced);

    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<void>> markSyncing(String itemId) async {
    _replaceStatus(itemId, SyncQueueStatus.syncing);

    return const AppSuccess<void>(null);
  }

  void _replaceStatus(
    String itemId,
    SyncQueueStatus status, {
    String? lastError,
  }) {
    final index = _items.indexWhere((item) => item.id == itemId);
    final item = _items[index];
    _items[index] = SyncQueueItem(
      id: item.id,
      entityType: item.entityType,
      entityId: item.entityId,
      operation: item.operation,
      payload: item.payload,
      status: status,
      retryCount: item.retryCount,
      lastError: lastError,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }
}

final class _SuccessfulRemoteSenderFake implements ISyncRemoteSender {
  const _SuccessfulRemoteSenderFake();

  @override
  Future<void> push(SyncQueueItem item) async {}
}

final class _SyncSettingsRepositoryFake implements ISyncSettingsRepository {
  SyncSettings settings = const SyncSettings();

  @override
  Future<AppResult<SyncSettings>> getSettings() async {
    return AppSuccess(settings);
  }

  @override
  Future<AppResult<SyncSettings>> saveSettings(SyncSettings settings) async {
    this.settings = settings;

    return AppSuccess(settings);
  }
}
