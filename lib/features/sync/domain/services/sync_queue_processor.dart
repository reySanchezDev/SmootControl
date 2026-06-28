import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_process_summary.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

/// Processes pending sync queue items in FIFO order.
final class SyncQueueProcessor {
  /// Creates a sync queue processor.
  const SyncQueueProcessor({
    required ISyncQueueRepository repository,
    required ISyncRemoteSender remoteSender,
  }) : _repository = repository,
       _remoteSender = remoteSender;

  final ISyncQueueRepository _repository;
  final ISyncRemoteSender _remoteSender;

  /// Sends pending queue items and updates their local state.
  Future<AppResult<SyncProcessSummary>> processPending({
    int limit = 50,
  }) async {
    final pendingResult = await _repository.getPendingItems(limit: limit);

    return pendingResult.when(
      success: _processItems,
      failure: AppFailureResult.new,
    );
  }

  Future<AppResult<SyncProcessSummary>> _processItems(
    List<SyncQueueItem> items,
  ) async {
    var succeeded = 0;
    var failed = 0;

    for (final item in items) {
      final syncingResult = await _repository.markSyncing(item.id);
      if (syncingResult.isFailure) {
        failed++;
        continue;
      }

      try {
        await _remoteSender.push(item);
        final syncedResult = await _repository.markSynced(item.id);
        if (syncedResult.isSuccess) {
          succeeded++;
        } else {
          failed++;
        }
      } on Object catch (error) {
        failed++;
        await _repository.markError(
          itemId: item.id,
          error: error.toString(),
        );
      }
    }

    return AppSuccess(
      SyncProcessSummary(
        processed: items.length,
        succeeded: succeeded,
        failed: failed,
      ),
    );
  }
}
