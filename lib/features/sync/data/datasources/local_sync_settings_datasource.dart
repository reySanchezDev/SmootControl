import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_settings.dart';

/// Local datasource for synchronization settings.
final class LocalSyncSettingsDataSource {
  /// Creates a local sync settings datasource.
  const LocalSyncSettingsDataSource(this._database);

  static const _settingsId = 'default';

  final AppDatabase _database;

  /// Reads the saved settings row, when present.
  Future<SyncSettings?> getSettings() async {
    final row = await (_database.select(
      _database.localSyncSettings,
    )..where((settings) => settings.id.equals(_settingsId))).getSingleOrNull();
    if (row == null) return null;

    return SyncSettings(
      autoSyncEnabled: row.autoSyncEnabled,
      intervalMinutes: row.intervalMinutes,
      syncOnStartup: row.syncOnStartup,
      syncOnSave: row.syncOnSave,
      updatedAt: row.updatedAt,
    ).normalized();
  }

  /// Saves the settings row.
  Future<SyncSettings> saveSettings(SyncSettings settings) async {
    final updatedAt = DateTime.now();
    final normalized = settings.normalized().copyWith(
      updatedAt: updatedAt,
    );
    await _database
        .into(_database.localSyncSettings)
        .insertOnConflictUpdate(
          LocalSyncSettingsCompanion(
            id: const Value(_settingsId),
            autoSyncEnabled: Value(normalized.autoSyncEnabled),
            intervalMinutes: Value(normalized.intervalMinutes),
            syncOnStartup: Value(normalized.syncOnStartup),
            syncOnSave: Value(normalized.syncOnSave),
            updatedAt: Value(updatedAt),
          ),
        );

    return normalized;
  }
}
