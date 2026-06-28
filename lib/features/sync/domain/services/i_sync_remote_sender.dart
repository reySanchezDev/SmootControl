import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

/// Contract used by the sync processor to push one item remotely.
// ignore: one_member_abstracts
abstract interface class ISyncRemoteSender {
  /// Pushes one queued operation to the remote backend.
  Future<void> push(SyncQueueItem item);
}
