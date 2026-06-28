import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/cash_register/data/datasources/local_cash_register_datasource.dart';
import 'package:smoo_control/features/cash_register/data/repositories/cash_register_repository.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_summary.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

void main() {
  group('CashRegisterRepository', () {
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

    test('opens and closes a local cash register session', () async {
      final session = CashRegisterSession(
        id: 'session-1',
        cashierId: 'cashier-1',
        businessDate: DateTime(2026, 6, 23),
        openingCashInCents: 10000,
        status: CashRegisterStatus.open,
      );

      final openResult = await repository.openSession(session);
      await _seedCashSummaryRows(database);
      final openedResult = await repository.getOpenSession(
        DateTime(2026, 6, 23),
      );
      final sessionsResult = await repository.getSessions(
        from: DateTime(2026, 6, 23),
        to: DateTime(2026, 6, 24),
      );
      final summaryResult = await repository.getSummary(session);
      final closeResult = await repository.closeSession(
        sessionId: 'session-1',
        physicalClosingCashInCents: 25000,
      );
      final syncResult = await syncQueueRepository.getPendingItems();
      final opened = (openedResult as AppSuccess<CashRegisterSession?>).value;
      final sessions =
          (sessionsResult as AppSuccess<List<CashRegisterSession>>).value;
      final summary = (summaryResult as AppSuccess<CashRegisterSummary>).value;
      final closed = (closeResult as AppSuccess<CashRegisterSession>).value;
      final syncItems = (syncResult as AppSuccess<List<SyncQueueItem>>).value;

      expect(openResult, isA<AppSuccess<CashRegisterSession>>());
      expect(opened?.id, 'session-1');
      expect(sessions.single.id, 'session-1');
      expect(summary.cashSalesInCents, 7000);
      expect(summary.expensesInCents, 2000);
      expect(summary.expectedClosingCashInCents, 15000);
      expect(closed.status, CashRegisterStatus.closed);
      expect(closed.physicalClosingCashInCents, 25000);
      expect(syncItems, hasLength(2));
      expect(syncItems.first.operation, SyncOperation.create);
      expect(syncItems.last.operation, SyncOperation.update);
      expect(syncItems.last.entityType, 'cash_register_sessions');
    });

    test(
      'prevents two open cash registers for the same cashier and date',
      () async {
        final firstSession = CashRegisterSession(
          id: 'session-1',
          cashierId: 'cashier-1',
          businessDate: DateTime(2026, 6, 23),
          openingCashInCents: 10000,
          status: CashRegisterStatus.open,
        );
        final secondSession = CashRegisterSession(
          id: 'session-2',
          cashierId: 'cashier-1',
          businessDate: DateTime(2026, 6, 23),
          openingCashInCents: 20000,
          status: CashRegisterStatus.open,
        );

        await repository.openSession(firstSession);
        final secondResult = await repository.openSession(secondSession);
        final sessionsResult = await repository.getSessions(
          from: DateTime(2026, 6, 23),
          to: DateTime(2026, 6, 24),
        );
        final syncResult = await syncQueueRepository.getPendingItems();
        final sessions =
            (sessionsResult as AppSuccess<List<CashRegisterSession>>).value;
        final syncItems = (syncResult as AppSuccess<List<SyncQueueItem>>).value;

        expect(secondResult, isA<AppFailureResult<CashRegisterSession>>());
        expect(
          (secondResult as AppFailureResult<CashRegisterSession>).error.code,
          'cash_register_already_open',
        );
        expect(sessions, hasLength(1));
        expect(sessions.single.id, 'session-1');
        expect(syncItems, hasLength(1));
      },
    );

    test(
      'prevents opening today when the cashier left a previous day open',
      () async {
        final previousSession = CashRegisterSession(
          id: 'session-previous',
          cashierId: 'cashier-1',
          businessDate: DateTime(2026, 6, 23),
          openingCashInCents: 10000,
          status: CashRegisterStatus.open,
        );
        final todaySession = CashRegisterSession(
          id: 'session-today',
          cashierId: 'cashier-1',
          businessDate: DateTime(2026, 6, 24),
          openingCashInCents: 20000,
          status: CashRegisterStatus.open,
        );

        await repository.openSession(previousSession);
        final todayResult = await repository.openSession(todaySession);
        final anyOpenResult = await repository.getAnyOpenSessionForCashier(
          'cashier-1',
        );
        final anyOpen =
            (anyOpenResult as AppSuccess<CashRegisterSession?>).value;

        expect(todayResult, isA<AppFailureResult<CashRegisterSession>>());
        expect(
          (todayResult as AppFailureResult<CashRegisterSession>).error.code,
          'cash_register_previous_day_open',
        );
        expect(anyOpen?.id, 'session-previous');
      },
    );

    test('allows separate cash registers for different cashiers', () async {
      final firstSession = CashRegisterSession(
        id: 'session-1',
        cashierId: 'cashier-1',
        businessDate: DateTime(2026, 6, 23),
        openingCashInCents: 10000,
        status: CashRegisterStatus.open,
      );
      final secondSession = CashRegisterSession(
        id: 'session-2',
        cashierId: 'cashier-2',
        businessDate: DateTime(2026, 6, 23),
        openingCashInCents: 20000,
        status: CashRegisterStatus.open,
      );

      await repository.openSession(firstSession);
      final secondResult = await repository.openSession(secondSession);
      final cashierSessionResult = await repository.getOpenSessionForCashier(
        businessDate: DateTime(2026, 6, 23),
        cashierId: 'cashier-2',
      );
      final sessionsResult = await repository.getSessions(
        from: DateTime(2026, 6, 23),
        to: DateTime(2026, 6, 24),
      );
      final sessions =
          (sessionsResult as AppSuccess<List<CashRegisterSession>>).value;
      final cashierSession =
          (cashierSessionResult as AppSuccess<CashRegisterSession?>).value;

      expect(secondResult, isA<AppSuccess<CashRegisterSession>>());
      expect(cashierSession?.id, 'session-2');
      expect(sessions, hasLength(2));
    });
  });
}

Future<void> _seedCashSummaryRows(AppDatabase database) async {
  final now = DateTime(2026, 6, 23, 10);
  await database
      .into(database.localPaymentMethods)
      .insert(
        LocalPaymentMethodsCompanion.insert(
          id: 'cash',
          name: 'Efectivo',
          affectsCashRegister: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localPaymentMethods)
      .insert(
        LocalPaymentMethodsCompanion.insert(
          id: 'card',
          name: 'Tarjeta',
          affectsCashRegister: const Value(false),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localSales)
      .insert(
        LocalSalesCompanion.insert(
          id: 'sale-cash',
          invoiceNumber: 'F-1',
          cashRegisterSessionId: const Value('session-1'),
          paymentMethodId: 'cash',
          subtotalInCents: 7000,
          totalInCents: 7000,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localSales)
      .insert(
        LocalSalesCompanion.insert(
          id: 'sale-card',
          invoiceNumber: 'F-2',
          cashRegisterSessionId: const Value('session-1'),
          paymentMethodId: 'card',
          subtotalInCents: 3000,
          totalInCents: 3000,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.localOperatingExpenses)
      .insert(
        LocalOperatingExpensesCompanion.insert(
          id: 'expense-1',
          categoryId: 'category-1',
          cashRegisterSessionId: const Value('session-1'),
          amountInCents: 2000,
          description: 'Compra local',
          createdBy: 'usuario-local',
          createdAt: now,
          updatedAt: now,
        ),
      );
}
