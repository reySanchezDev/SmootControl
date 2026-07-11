import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/staff/data/datasources/local_staff_datasource.dart';
import 'package:smoo_control/features/staff/data/repositories/staff_pos_repository.dart';
import 'package:smoo_control/features/staff/domain/entities/salary_advance.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';

void main() {
  group('StaffPosRepository', () {
    late AppDatabase database;
    late _SyncQueueRepositoryFake syncQueue;
    late StaffPosRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueue = _SyncQueueRepositoryFake();
      repository = StaffPosRepository(
        LocalStaffDataSource(database),
        syncQueueRepository: syncQueue,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('saves salary advances locally and enqueues remote sync', () async {
      final createdAt = DateTime(2026, 7, 8, 10);
      final advance = SalaryAdvance(
        id: 'advance-1',
        employeeId: 'employee-1',
        cashRegisterSessionId: 'cash-1',
        amountInCents: 52500,
        affectsCash: true,
        note: 'Adelanto POS',
        createdBy: 'cashier-1',
        createdAt: createdAt,
        deliveredAt: createdAt,
      );

      final result = await repository.saveSalaryAdvance(advance);

      expect(result, isA<AppSuccess<SalaryAdvance>>());
      final local = await database
          .select(database.localSalaryAdvances)
          .getSingle();
      expect(local.id, 'advance-1');
      expect(local.amountInCents, 52500);

      expect(syncQueue.items, hasLength(1));
      final syncItem = syncQueue.items.single;
      expect(syncItem.entityType, 'salary_advances');
      expect(syncItem.entityId, 'advance-1');
      expect(syncItem.operation, SyncOperation.create);
      expect(syncItem.payload['employeeId'], 'employee-1');
      expect(syncItem.payload['amountInCents'], 52500);
      expect(syncItem.payload['affectsCash'], true);
      expect(syncItem.payload['cashRegisterSessionId'], 'cash-1');
      expect(syncItem.payload['deliveredAt'], createdAt.toIso8601String());
    });
  });
}

final class _SyncQueueRepositoryFake implements ISyncQueueRepository {
  final items = <SyncQueueItem>[];

  @override
  Future<AppResult<SyncQueueItem>> enqueue({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, Object?> payload,
  }) async {
    final item = SyncQueueItem(
      id: 'queue-${items.length + 1}',
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      status: SyncQueueStatus.pending,
      retryCount: 0,
      createdAt: DateTime(2026, 7, 8),
      updatedAt: DateTime(2026, 7, 8),
    );
    items.add(item);
    return AppSuccess(item);
  }

  @override
  Future<AppResult<List<SyncQueueItem>>> getPendingItems({int limit = 50}) {
    return Future.value(AppSuccess(items.take(limit).toList()));
  }

  @override
  Future<AppResult<void>> markError({
    required String itemId,
    required String error,
  }) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<void>> markSynced(String itemId) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<void>> markSyncing(String itemId) async {
    return const AppSuccess(null);
  }
}
