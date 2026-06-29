import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_settings_datasource.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_settings.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_settings_repository.dart';

/// Synchronization settings repository backed by local storage.
final class SyncSettingsRepository implements ISyncSettingsRepository {
  /// Creates a synchronization settings repository.
  const SyncSettingsRepository(this._localDataSource);

  final LocalSyncSettingsDataSource _localDataSource;

  @override
  Future<AppResult<SyncSettings>> getSettings() async {
    try {
      return AppSuccess(
        await _localDataSource.getSettings() ?? const SyncSettings(),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sync_settings_read_failed',
          message: 'No se pudo leer la configuracion de sincronizacion.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<SyncSettings>> saveSettings(SyncSettings settings) async {
    try {
      return AppSuccess(await _localDataSource.saveSettings(settings));
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'sync_settings_save_failed',
          message: 'No se pudo guardar la configuracion de sincronizacion.',
          cause: error,
        ),
      );
    }
  }
}
