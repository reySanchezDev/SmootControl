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
    Duration remoteTimeout = const Duration(seconds: 30),
  }) : _repository = repository,
       _remoteSender = remoteSender,
       _remoteTimeout = remoteTimeout;

  final ISyncQueueRepository _repository;
  final ISyncRemoteSender _remoteSender;
  final Duration _remoteTimeout;

  /// Sends pending queue items and updates their local state.
  Future<AppResult<SyncProcessSummary>> processPending({
    int limit = 50,
  }) async {
    var processed = 0;
    var succeeded = 0;
    var failed = 0;

    while (true) {
      final pendingResult = await _repository.getPendingItems(limit: limit);
      switch (pendingResult) {
        case AppFailureResult(:final error):
          return AppFailureResult(error);
        case AppSuccess(:final value):
          if (value.isEmpty) {
            return AppSuccess(
              SyncProcessSummary(
                processed: processed,
                succeeded: succeeded,
                failed: failed,
              ),
            );
          }

          final summary = await _processItems(value);
          processed += summary.processed;
          succeeded += summary.succeeded;
          failed += summary.failed;

          if (summary.failed > 0 || value.length < limit) {
            return AppSuccess(
              SyncProcessSummary(
                processed: processed,
                succeeded: succeeded,
                failed: failed,
              ),
            );
          }
      }
    }
  }

  Future<SyncProcessSummary> _processItems(List<SyncQueueItem> items) async {
    var succeeded = 0;
    var failed = 0;

    for (final item in items) {
      final syncingResult = await _repository.markSyncing(item.id);
      if (syncingResult.isFailure) {
        failed++;
        continue;
      }

      try {
        await _remoteSender.push(item).timeout(_remoteTimeout);
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

    return SyncProcessSummary(
      processed: items.length,
      succeeded: succeeded,
      failed: failed,
    );
  }
}
