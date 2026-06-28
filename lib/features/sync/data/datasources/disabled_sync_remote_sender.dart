import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

/// Remote sync sender used until the SmooControl Supabase project is ready.
final class DisabledSyncRemoteSender implements ISyncRemoteSender {
  /// Creates a disabled remote sync sender.
  const DisabledSyncRemoteSender();

  @override
  Future<void> push(SyncQueueItem item) {
    throw StateError('Sincronizacion remota pendiente de configurar.');
  }
}
