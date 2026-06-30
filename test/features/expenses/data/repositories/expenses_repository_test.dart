import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/expenses/data/datasources/local_expenses_datasource.dart';
import 'package:smoo_control/features/expenses/data/models/expense_category_model.dart';
import 'package:smoo_control/features/expenses/data/repositories/expenses_repository.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

void main() {
  group('ExpensesRepository', () {
    late AppDatabase database;
    late LocalExpensesDataSource dataSource;
    late ExpensesRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      dataSource = LocalExpensesDataSource(database);
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = ExpensesRepository(
        dataSource,
        syncQueueRepository: syncQueueRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('reads categories and saves local expenses', () async {
      await dataSource.saveCategory(
        const ExpenseCategoryModel(
          id: 'category-1',
          name: 'Nomina',
          isActive: true,
        ),
      );

      final expense = OperatingExpense(
        id: 'expense-1',
        categoryId: 'category-1',
        amountInCents: 15000,
        description: 'Pago de colaborador',
        createdAt: DateTime(2026, 6, 23),
        createdBy: 'admin-1',
      );

      final categoriesResult = await repository.getCategories();
      final saveResult = await repository.saveExpense(expense);
      final expensesResult = await repository.getExpenses(
        from: DateTime(2026, 6, 23),
        to: DateTime(2026, 6, 24),
      );
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(categoriesResult, isA<AppSuccess<List<ExpenseCategory>>>());
      expect(saveResult, isA<AppSuccess<OperatingExpense>>());
      expect(expensesResult, isA<AppSuccess<List<OperatingExpense>>>());
      expect(
        (saveResult as AppSuccess<OperatingExpense>).value,
        expense,
      );
      expect(
        (expensesResult as AppSuccess<List<OperatingExpense>>).value,
        [expense],
      );
      final syncItem =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(syncItem.entityType, 'operating_expenses');
      expect(syncItem.entityId, expense.id);
      expect(syncItem.operation, SyncOperation.create);
    });

    test('deletes a category and moves children to root', () async {
      await dataSource.saveCategory(
        const ExpenseCategoryModel(
          id: 'group-1',
          name: 'Combustible',
          isActive: true,
        ),
      );
      await dataSource.saveCategory(
        const ExpenseCategoryModel(
          id: 'category-1',
          name: 'Gasolina',
          parentId: 'group-1',
          isActive: true,
        ),
      );

      final deleteResult = await repository.deleteCategory('group-1');
      final categoriesResult = await repository.getCategories();

      expect(deleteResult, isA<AppSuccess<void>>());
      final categories =
          (categoriesResult as AppSuccess<List<ExpenseCategory>>).value;
      expect(categories.map((category) => category.id), ['category-1']);
      expect(categories.single.parentId, isNull);
    });

    test('does not delete local category when remote delete fails', () async {
      await dataSource.saveCategory(
        const ExpenseCategoryModel(
          id: 'group-1',
          name: 'Combustible',
          isActive: true,
        ),
      );
      final remoteFirstRepository = ExpensesRepository(
        dataSource,
        syncQueueRepository: syncQueueRepository,
        remoteSender: const _FailingRemoteSender(),
      );

      final deleteResult = await remoteFirstRepository.deleteCategory(
        'group-1',
      );
      final categoriesResult = await repository.getCategories();

      expect(deleteResult, isA<AppFailureResult<void>>());
      final categories =
          (categoriesResult as AppSuccess<List<ExpenseCategory>>).value;
      expect(categories.any((category) => category.id == 'group-1'), isTrue);
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
