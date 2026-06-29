import 'package:equatable/equatable.dart';

/// Local operator configuration for automatic synchronization.
final class SyncSettings extends Equatable {
  /// Creates synchronization settings.
  const SyncSettings({
    this.autoSyncEnabled = true,
    this.intervalMinutes = 5,
    this.syncOnStartup = true,
    this.syncOnSave = true,
    this.updatedAt,
  });

  /// Whether periodic automatic sync is enabled.
  final bool autoSyncEnabled;

  /// Interval in minutes used by the automatic scheduler.
  final int intervalMinutes;

  /// Whether pending items should be retried when the app starts.
  final bool syncOnStartup;

  /// Whether each saved operation should attempt an immediate remote push.
  final bool syncOnSave;

  /// Last settings update timestamp.
  final DateTime? updatedAt;

  /// Returns a copy constrained to operationally safe values.
  SyncSettings normalized() {
    return copyWith(
      intervalMinutes: intervalMinutes.clamp(1, 1440),
    );
  }

  /// Creates a modified copy.
  SyncSettings copyWith({
    bool? autoSyncEnabled,
    int? intervalMinutes,
    bool? syncOnStartup,
    bool? syncOnSave,
    DateTime? updatedAt,
  }) {
    return SyncSettings(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      syncOnStartup: syncOnStartup ?? this.syncOnStartup,
      syncOnSave: syncOnSave ?? this.syncOnSave,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    autoSyncEnabled,
    intervalMinutes,
    syncOnStartup,
    syncOnSave,
    updatedAt,
  ];
}
