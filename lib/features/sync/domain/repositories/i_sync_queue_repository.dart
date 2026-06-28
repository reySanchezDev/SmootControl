import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

/// Contract for local synchronization queue operations.
abstract interface class ISyncQueueRepository {
  /// Enqueues a pending remote operation.
  Future<AppResult<SyncQueueItem>> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, Object?> payload,
  });

  /// Returns pending or failed queue items eligible for processing.
  Future<AppResult<List<SyncQueueItem>>> getPendingItems({int limit = 50});

  /// Marks an item as syncing.
  Future<AppResult<void>> markSyncing(String itemId);

  /// Marks an item as synced.
  Future<AppResult<void>> markSynced(String itemId);

  /// Marks an item as failed.
  Future<AppResult<void>> markError({
    required String itemId,
    required String error,
  });
}
