import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/models/sync_queue_item_model.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:uuid/uuid.dart';

/// Sync queue repository backed by the local offline database.
final class SyncQueueRepository implements ISyncQueueRepository {
  /// Creates a sync queue repository.
  const SyncQueueRepository(
    this._localDataSource, {
    Uuid uuid = const Uuid(),
  }) : _uuid = uuid;

  final LocalSyncQueueDataSource _localDataSource;
  final Uuid _uuid;

  @override
  Future<AppResult<SyncQueueItem>> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, Object?> payload,
  }) async {
    try {
      final now = DateTime.now();
      final item = SyncQueueItemModel(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      final saved = await _localDataSource.saveItem(item);

      return AppSuccess(saved.toEntity());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sync_enqueue_failed',
          message: 'No se pudo agregar la operacion a la cola local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<SyncQueueItem>>> getPendingItems({
    int limit = 50,
  }) async {
    try {
      final items = await _localDataSource.getPendingItems(limit: limit);

      return AppSuccess(items.map((item) => item.toEntity()).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sync_queue_read_failed',
          message: 'No se pudo leer la cola de sincronizacion local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> markError({
    required String itemId,
    required String error,
  }) {
    return _runStatusUpdate(
      () => _localDataSource.markError(itemId: itemId, error: error),
    );
  }

  @override
  Future<AppResult<void>> markSynced(String itemId) {
    return _runStatusUpdate(() => _localDataSource.markSynced(itemId));
  }

  @override
  Future<AppResult<void>> markSyncing(String itemId) {
    return _runStatusUpdate(() => _localDataSource.markSyncing(itemId));
  }

  Future<AppResult<void>> _runStatusUpdate(Future<void> Function() run) async {
    try {
      await run();

      return const AppSuccess<void>(null);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sync_status_update_failed',
          message: 'No se pudo actualizar el estado de sincronizacion.',
          cause: error,
        ),
      );
    }
  }
}
