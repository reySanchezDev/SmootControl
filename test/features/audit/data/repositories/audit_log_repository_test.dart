import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/data/datasources/local_audit_log_datasource.dart';
import 'package:smoo_control/features/audit/data/repositories/audit_log_repository.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

void main() {
  group('AuditLogRepository', () {
    late AppDatabase database;
    late AuditLogRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = AuditLogRepository(
        LocalAuditLogDataSource(database),
        syncQueueRepository: syncQueueRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('saves and returns audit entries by date', () async {
      final date = DateTime(2026, 6, 24, 9);
      final entry = AuditLogEntry(
        id: 'audit-1',
        actorUserId: 'user-1',
        action: 'ventas.anular',
        entityName: 'sales',
        entityId: 'sale-1',
        details: const {'reason': 'Error de cajero'},
        occurredAt: date,
      );

      final saveResult = await repository.saveEntry(entry);
      final readResult = await repository.getEntriesByDate(date);
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppSuccess<AuditLogEntry>>());
      expect((readResult as AppSuccess<List<AuditLogEntry>>).value, [entry]);
      final syncItem =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(syncItem.entityType, 'audit_logs');
      expect(syncItem.entityId, entry.id);
      expect(syncItem.operation, SyncOperation.create);
    });

    test('does not return entries from another day', () async {
      final entry = AuditLogEntry(
        id: 'audit-1',
        action: 'settings.actualizar',
        entityName: 'settings',
        details: const {},
        occurredAt: DateTime(2026, 6, 23, 23, 59),
      );

      await repository.saveEntry(entry);
      final result = await repository.getEntriesByDate(DateTime(2026, 6, 24));

      expect((result as AppSuccess<List<AuditLogEntry>>).value, isEmpty);
    });
  });
}
