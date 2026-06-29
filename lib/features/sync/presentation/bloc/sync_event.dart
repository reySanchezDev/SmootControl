import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_settings.dart';

/// Base event for synchronization UI.
sealed class SyncEvent extends Equatable {
  /// Creates a sync event.
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the local synchronization queue.
final class SyncQueueRequested extends SyncEvent {
  /// Creates a load event.
  const SyncQueueRequested();
}

/// Processes pending local synchronization items.
final class SyncProcessRequested extends SyncEvent {
  /// Creates a process event.
  const SyncProcessRequested();
}

/// Saves synchronization settings.
final class SyncSettingsSaved extends SyncEvent {
  /// Creates a settings save event.
  const SyncSettingsSaved(this.settings);

  /// Settings to persist.
  final SyncSettings settings;

  @override
  List<Object?> get props => [settings];
}
