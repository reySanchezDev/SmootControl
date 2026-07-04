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
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

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

    test('can save the local invoice cursor without remote sync', () async {
      const settings = BusinessSettings(
        businessName: 'Casa del Cafe',
        showCompanyInfoOnReceipts: true,
        invoicePrefix: 'F',
        initialInvoiceNumber: 1,
        nextInvoiceNumber: 2,
      );

      final saveResult = await repository.saveSettings(
        settings,
        syncRemote: false,
      );
      final readResult = await repository.getSettings();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppSuccess<BusinessSettings>>());
      expect((readResult as AppSuccess<BusinessSettings>).value, settings);
      expect((syncResult as AppSuccess<List<SyncQueueItem>>).value, isEmpty);
    });

    test('does not save local settings when remote-first push fails', () async {
      repository = BusinessSettingsRepository(
        LocalBusinessSettingsDataSource(database),
        syncQueueRepository: syncQueueRepository,
        remoteSender: const _FailingRemoteSender(),
      );
      const settings = BusinessSettings(
        businessName: 'Casa del Cafe',
        showCompanyInfoOnReceipts: true,
        invoicePrefix: 'F',
        initialInvoiceNumber: 1,
        nextInvoiceNumber: 1,
      );

      final saveResult = await repository.saveSettings(settings);
      final readResult = await repository.getSettings();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppFailureResult<BusinessSettings>>());
      expect(
        (readResult as AppSuccess<BusinessSettings>).value,
        BusinessSettings.empty,
      );
      expect((syncResult as AppSuccess<List<SyncQueueItem>>).value, isEmpty);
    });
  });
}

final class _FailingRemoteSender implements ISyncRemoteSender {
  const _FailingRemoteSender();

  @override
  Future<void> push(SyncQueueItem item) {
    throw StateError('remote failed');
  }
}
