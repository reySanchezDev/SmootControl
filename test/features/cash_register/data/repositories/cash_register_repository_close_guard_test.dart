import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/cash_register/data/datasources/local_cash_register_datasource.dart';
import 'package:smoo_control/features/cash_register/data/repositories/cash_register_repository.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

void main() {
  group('CashRegisterRepository close guards', () {
    late AppDatabase database;
    late CashRegisterRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = CashRegisterRepository(
        LocalCashRegisterDataSource(database),
        syncQueueRepository: syncQueueRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('does not enqueue another close for a closed session', () async {
      await repository.openSession(_session('session-1'));
      await repository.closeSession(
        sessionId: 'session-1',
        physicalClosingCashInCents: 25000,
      );

      final secondClose = await repository.closeSession(
        sessionId: 'session-1',
        physicalClosingCashInCents: 30000,
      );
      final syncResult = await syncQueueRepository.getPendingItems();
      final closed = (secondClose as AppSuccess<CashRegisterSession>).value;
      final syncItems = (syncResult as AppSuccess<List<SyncQueueItem>>).value;

      expect(closed.physicalClosingCashInCents, 25000);
      expect(syncItems, hasLength(2));
      expect(syncItems.last.operation, SyncOperation.update);
    });

    test('prevents opening after closing the same date', () async {
      await repository.openSession(_session('session-1'));
      await repository.closeSession(
        sessionId: 'session-1',
        physicalClosingCashInCents: 25000,
      );

      final secondResult = await repository.openSession(_session('session-2'));
      final sessionsResult = await repository.getSessions(
        from: DateTime(2026, 6, 23),
        to: DateTime(2026, 6, 24),
      );
      final sessions =
          (sessionsResult as AppSuccess<List<CashRegisterSession>>).value;

      expect(secondResult, isA<AppFailureResult<CashRegisterSession>>());
      expect(
        (secondResult as AppFailureResult<CashRegisterSession>).error.code,
        'cash_register_day_already_closed',
      );
      expect(sessions, hasLength(1));
      expect(sessions.single.id, 'session-1');
    });
  });
}

CashRegisterSession _session(String id) {
  return CashRegisterSession(
    id: id,
    cashierId: 'cashier-1',
    businessDate: DateTime(2026, 6, 23),
    openingCashInCents: 10000,
    status: CashRegisterStatus.open,
  );
}
