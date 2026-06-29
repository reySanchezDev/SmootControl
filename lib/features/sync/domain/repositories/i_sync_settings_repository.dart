import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_settings.dart';

/// Contract for local synchronization settings.
abstract interface class ISyncSettingsRepository {
  /// Returns the current synchronization settings.
  Future<AppResult<SyncSettings>> getSettings();

  /// Saves synchronization settings.
  Future<AppResult<SyncSettings>> saveSettings(SyncSettings settings);
}
