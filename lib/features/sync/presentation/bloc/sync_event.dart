import 'package:equatable/equatable.dart';

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
