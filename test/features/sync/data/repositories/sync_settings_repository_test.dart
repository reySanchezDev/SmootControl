import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_settings_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_settings_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_settings.dart';

void main() {
  group('SyncSettingsRepository', () {
    late AppDatabase database;
    late SyncSettingsRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = SyncSettingsRepository(
        LocalSyncSettingsDataSource(database),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('returns operational defaults when no settings were saved', () async {
      final result = await repository.getSettings();

      final settings = (result as AppSuccess<SyncSettings>).value;
      expect(settings.autoSyncEnabled, isTrue);
      expect(settings.intervalMinutes, 5);
      expect(settings.syncOnStartup, isTrue);
      expect(settings.syncOnSave, isTrue);
    });

    test('saves synchronization settings locally', () async {
      await repository.saveSettings(
        const SyncSettings(
          autoSyncEnabled: false,
          intervalMinutes: 10,
          syncOnStartup: false,
          syncOnSave: false,
        ),
      );

      final result = await repository.getSettings();

      final settings = (result as AppSuccess<SyncSettings>).value;
      expect(settings.autoSyncEnabled, isFalse);
      expect(settings.intervalMinutes, 10);
      expect(settings.syncOnStartup, isFalse);
      expect(settings.syncOnSave, isFalse);
    });
  });
}
