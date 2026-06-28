import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/settings/data/datasources/local_business_settings_datasource.dart';
import 'package:smoo_control/features/settings/data/repositories/business_settings_repository.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

void main() {
  group('BusinessSettingsRepository', () {
    late AppDatabase database;
    late BusinessSettingsRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = BusinessSettingsRepository(
        LocalBusinessSettingsDataSource(database),
        syncQueueRepository: syncQueueRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('returns default settings when none were saved', () async {
      final result = await repository.getSettings();

      expect(result, isA<AppSuccess<BusinessSettings>>());
      expect(
        (result as AppSuccess<BusinessSettings>).value,
        BusinessSettings.empty,
      );
    });

    test('saves and returns business settings', () async {
      const settings = BusinessSettings(
        businessName: 'Casa del Cafe',
        legalName: 'Casa del Cafe S.A.',
        taxNumber: 'J0310000000000',
        phone: '2222-2222',
        address: 'Managua',
        showCompanyInfoOnReceipts: true,
        invoicePrefix: 'F',
        initialInvoiceNumber: 100,
        nextInvoiceNumber: 100,
      );

      final saveResult = await repository.saveSettings(settings);
      final readResult = await repository.getSettings();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppSuccess<BusinessSettings>>());
      expect((readResult as AppSuccess<BusinessSettings>).value, settings);
      final syncItem =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(syncItem.entityType, 'business_settings');
      expect(syncItem.entityId, 'default');
      expect(syncItem.operation, SyncOperation.update);
      expect(syncItem.payload['businessName'], settings.businessName);
    });
  });
}
