import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sync/data/models/sync_queue_item_model.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

/// Local datasource for the offline synchronization queue.
final class LocalSyncQueueDataSource {
  /// Creates a local sync queue datasource.
  const LocalSyncQueueDataSource(this._database);

  static const _staleSyncingAge = Duration(minutes: 2);

  final AppDatabase _database;

  /// Inserts or updates a queue item.
  Future<SyncQueueItemModel> saveItem(SyncQueueItemModel item) async {
    await _database
        .into(_database.localSyncQueue)
        .insertOnConflictUpdate(
          LocalSyncQueueCompanion(
            id: Value(item.id),
            entityType: Value(item.entityType),
            entityId: Value(item.entityId),
            operation: Value(item.operation.name),
            payloadJson: Value(item.payloadJson),
            status: Value(item.status.name),
            retryCount: Value(item.retryCount),
            lastError: Value(item.lastError),
            createdAt: Value(item.createdAt),
            updatedAt: Value(item.updatedAt),
          ),
        );

    return item;
  }

  /// Returns items waiting to be synchronized.
  Future<List<SyncQueueItemModel>> getPendingItems({int limit = 50}) async {
    final staleSyncingCutoff = DateTime.now().subtract(_staleSyncingAge);
    final query = _database.select(_database.localSyncQueue)
      ..where((item) {
        return item.status.equals(SyncQueueStatus.pending.name) |
            item.status.equals(SyncQueueStatus.error.name) |
            (item.status.equals(SyncQueueStatus.syncing.name) &
                item.updatedAt.isSmallerThanValue(staleSyncingCutoff));
      })
      ..orderBy([(item) => OrderingTerm.asc(item.createdAt)])
      ..limit(limit);
    final rows = await query.get();

    return rows.map(SyncQueueItemModel.fromLocal).toList();
  }

  /// Marks an item as syncing.
  Future<void> markSyncing(String itemId) async {
    await _updateStatus(
      itemId: itemId,
      status: SyncQueueStatus.syncing,
      clearError: true,
    );
  }

  /// Marks an item as synced.
  Future<void> markSynced(String itemId) async {
    await _updateStatus(
      itemId: itemId,
      status: SyncQueueStatus.synced,
      clearError: true,
    );
  }

  /// Marks an item as failed.
  Future<void> markError({
    required String itemId,
    required String error,
  }) async {
    final current = await (_database.select(
      _database.localSyncQueue,
    )..where((item) => item.id.equals(itemId))).getSingleOrNull();
    if (current == null) return;

    await (_database.update(
      _database.localSyncQueue,
    )..where((item) => item.id.equals(itemId))).write(
      LocalSyncQueueCompanion(
        status: Value(SyncQueueStatus.error.name),
        retryCount: Value(current.retryCount + 1),
        lastError: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _updateStatus({
    required String itemId,
    required SyncQueueStatus status,
    required bool clearError,
  }) async {
    await (_database.update(
      _database.localSyncQueue,
    )..where((item) => item.id.equals(itemId))).write(
      LocalSyncQueueCompanion(
        status: Value(status.name),
        lastError: clearError
            ? const Value<String?>(null)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
