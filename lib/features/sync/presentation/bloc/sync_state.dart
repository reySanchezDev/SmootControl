import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_process_summary.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_settings.dart';

/// Base state for synchronization UI.
sealed class SyncState extends Equatable {
  /// Creates a sync state.
  const SyncState();

  @override
  List<Object?> get props => [];
}

/// Initial synchronization state.
final class SyncInitial extends SyncState {
  /// Creates an initial state.
  const SyncInitial();
}

/// Loading synchronization data.
final class SyncLoading extends SyncState {
  /// Creates a loading state.
  const SyncLoading();
}

/// Local synchronization queue loaded.
final class SyncLoaded extends SyncState {
  /// Creates a loaded state.
  const SyncLoaded({
    required this.items,
    required this.settings,
    this.lastSummary,
    this.settingsSaved = false,
  });

  /// Pending or failed items visible to the operator.
  final List<SyncQueueItem> items;

  /// Current automatic synchronization settings.
  final SyncSettings settings;

  /// Last manual processing summary, when available.
  final SyncProcessSummary? lastSummary;

  /// Whether the current state was emitted after saving settings.
  final bool settingsSaved;

  @override
  List<Object?> get props => [items, settings, lastSummary, settingsSaved];
}

/// Synchronization failure state.
final class SyncFailure extends SyncState {
  /// Creates a failure state.
  const SyncFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
