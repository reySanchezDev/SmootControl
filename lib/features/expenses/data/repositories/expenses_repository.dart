import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/expenses/data/datasources/local_expenses_datasource.dart';
import 'package:smoo_control/features/expenses/data/models/expense_category_model.dart';
import 'package:smoo_control/features/expenses/data/models/operating_expense_model.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';
import 'package:smoo_control/features/expenses/domain/repositories/i_expenses_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

/// Expenses repository backed by the local offline database.
final class ExpensesRepository implements IExpensesRepository {
  /// Creates an expenses repository.
  const ExpensesRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    ISyncRemoteSender? remoteSender,
  }) : _syncQueueRepository = syncQueueRepository,
       _remoteSender = remoteSender;

  final LocalExpensesDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final ISyncRemoteSender? _remoteSender;

  @override
  Future<AppResult<List<ExpenseCategory>>> getCategories() async {
    try {
      final categories = await _localDataSource.getCategories();
      return AppSuccess(
        categories.map((category) => category.toEntity()).toList(),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'expense_categories_read_failed',
          message: 'No se pudieron leer las categorias de gastos locales.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<OperatingExpense>>> getExpenses({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final expenses = await _localDataSource.getExpenses(from: from, to: to);
      return AppSuccess(
        expenses.map((expense) => expense.toEntity()).toList(),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'expenses_read_failed',
          message: 'No se pudieron leer los gastos locales.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<ExpenseCategory>> saveCategory(
    ExpenseCategory category,
  ) async {
    try {
      final model = ExpenseCategoryModel.fromEntity(category);
      await _pushCategoryRemote(category);
      final saved = await _localDataSource.saveCategory(model);
      final entity = saved.toEntity();
      if (_remoteSender == null) {
        await _enqueueCategory(entity);
      }
      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'expense_category_save_failed',
          message: 'No se pudo guardar la categoria de gasto local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> deleteCategory(String categoryId) async {
    try {
      if (_remoteSender != null) {
        await _pushRemovedCategoryRemote(categoryId);
      }
      await _localDataSource.deleteCategory(categoryId);
      if (_remoteSender == null) {
        await _syncQueueRepository?.enqueue(
          entityType: 'expense_categories',
          entityId: categoryId,
          operation: SyncOperation.delete,
          payload: {'id': categoryId},
        );
      }
      return const AppSuccess(null);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'expense_category_delete_failed',
          message: 'No se pudo eliminar la categoria de gasto local.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<OperatingExpense>> saveExpense(
    OperatingExpense expense,
  ) async {
    try {
      final model = OperatingExpenseModel.fromEntity(expense);
      final saved = await _localDataSource.saveExpense(model);
      final entity = saved.toEntity();
      await _enqueueExpense(entity);

      return AppSuccess(entity);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'expense_save_failed',
          message: 'No se pudo guardar el gasto local.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _enqueueExpense(OperatingExpense expense) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'operating_expenses',
      entityId: expense.id,
      operation: SyncOperation.create,
      payload: {
        'id': expense.id,
        'categoryId': expense.categoryId,
        'cashRegisterSessionId': expense.cashRegisterSessionId,
        'amountInCents': expense.amountInCents,
        'description': expense.description,
        'createdAt': expense.createdAt.toIso8601String(),
        'createdBy': expense.createdBy,
      },
    );
  }

  Future<void> _enqueueCategory(ExpenseCategory category) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'expense_categories',
      entityId: category.id,
      operation: SyncOperation.create,
      payload: {
        'id': category.id,
        'name': category.name,
        'parentId': category.parentId,
        'isActive': category.isActive,
      },
    );
  }

  Future<void> _pushCategoryRemote(ExpenseCategory category) async {
    final remoteSender = _remoteSender;
    if (remoteSender == null) return;

    final now = DateTime.now();
    await remoteSender.push(
      SyncQueueItem(
        id: 'admin-direct-expense_categories-${category.id}',
        entityType: 'expense_categories',
        entityId: category.id,
        operation: SyncOperation.create,
        payload: {
          'id': category.id,
          'name': category.name,
          'parentId': category.parentId,
          'isActive': category.isActive,
        },
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _pushRemovedCategoryRemote(String categoryId) async {
    final remoteSender = _remoteSender;
    if (remoteSender == null) return;

    final now = DateTime.now();
    await remoteSender.push(
      SyncQueueItem(
        id: 'admin-direct-expense_categories-delete-$categoryId',
        entityType: 'expense_categories',
        entityId: categoryId,
        operation: SyncOperation.delete,
        payload: {'id': categoryId},
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
