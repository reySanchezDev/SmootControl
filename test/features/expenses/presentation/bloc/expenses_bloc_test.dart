import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';
import 'package:smoo_control/features/expenses/domain/repositories/i_expenses_repository.dart';
import 'package:smoo_control/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:smoo_control/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:smoo_control/features/expenses/presentation/bloc/expenses_state.dart';

void main() {
  group('ExpensesBloc', () {
    const category = ExpenseCategory(
      id: 'category-1',
      name: 'Nomina',
      isActive: true,
    );
    final expense = OperatingExpense(
      id: 'expense-1',
      categoryId: 'category-1',
      amountInCents: 15000,
      description: 'Pago',
      createdAt: DateTime(2026, 6, 23),
      createdBy: 'admin-1',
    );

    blocTest<ExpensesBloc, ExpensesState>(
      'loads expense categories',
      build: () => ExpensesBloc(
        repository: _ExpensesRepositoryFake(
          categoriesResult: const AppSuccess([category]),
        ),
        auditLogRepository: AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const ExpenseCategoriesLoadRequested()),
      expect: () => [
        const ExpensesLoading(),
        const ExpensesOverviewLoaded(
          categories: [category],
        ),
      ],
    );

    blocTest<ExpensesBloc, ExpensesState>(
      'saves expense and writes audit log',
      setUp: () {
        audit = AuditLogRepositoryFake();
      },
      build: () => ExpensesBloc(
        repository: _ExpensesRepositoryFake(
          saveResult: AppSuccess(expense),
        ),
        auditLogRepository: audit,
      ),
      act: (bloc) => bloc.add(ExpenseSaved(expense)),
      expect: () => [
        const ExpensesLoading(),
        const ExpensesOverviewLoaded(categories: []),
      ],
      verify: (_) {
        expect(audit.entries.single.action, 'expenses.save');
        expect(audit.entries.single.entityId, 'expense-1');
        expect(audit.entries.single.actorUserId, 'admin-1');
      },
    );

    blocTest<ExpensesBloc, ExpensesState>(
      'saves expense category and writes audit log',
      setUp: () {
        audit = AuditLogRepositoryFake();
      },
      build: () => ExpensesBloc(
        repository: _ExpensesRepositoryFake(
          categoriesResult: const AppSuccess([category]),
        ),
        auditLogRepository: audit,
      ),
      act: (bloc) => bloc.add(const ExpenseCategorySaved(category)),
      expect: () => const [
        ExpensesLoading(),
        ExpensesOverviewLoaded(categories: [category]),
      ],
      verify: (_) {
        expect(audit.entries.single.action, 'expenses.category.save');
        expect(audit.entries.single.entityId, 'category-1');
      },
    );

    blocTest<ExpensesBloc, ExpensesState>(
      'deletes expense category and writes audit log',
      setUp: () {
        audit = AuditLogRepositoryFake();
      },
      build: () => ExpensesBloc(
        repository: _ExpensesRepositoryFake(),
        auditLogRepository: audit,
      ),
      act: (bloc) => bloc.add(const ExpenseCategoryDeleted(category)),
      expect: () => const [
        ExpensesLoading(),
        ExpensesOverviewLoaded(categories: []),
      ],
      verify: (_) {
        expect(audit.entries.single.action, 'expenses.category.delete');
        expect(audit.entries.single.entityId, 'category-1');
      },
    );

    blocTest<ExpensesBloc, ExpensesState>(
      'emits failure when categories load fails',
      build: () => ExpensesBloc(
        repository: _ExpensesRepositoryFake(
          categoriesResult: const AppFailureResult(
            AppFailure(code: 'expenses_error', message: 'Error'),
          ),
        ),
        auditLogRepository: AuditLogRepositoryFake(),
      ),
      act: (bloc) => bloc.add(const ExpenseCategoriesLoadRequested()),
      expect: () => const [
        ExpensesLoading(),
        ExpensesFailure(AppFailure(code: 'expenses_error', message: 'Error')),
      ],
    );
  });
}

late AuditLogRepositoryFake audit;

final class _ExpensesRepositoryFake implements IExpensesRepository {
  _ExpensesRepositoryFake({
    this.categoriesResult = const AppSuccess([]),
    this.saveResult,
  });

  final AppResult<List<ExpenseCategory>> categoriesResult;
  final AppResult<OperatingExpense>? saveResult;

  @override
  Future<AppResult<List<ExpenseCategory>>> getCategories() async {
    return categoriesResult;
  }

  @override
  Future<AppResult<List<OperatingExpense>>> getExpenses({
    required DateTime from,
    required DateTime to,
  }) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<ExpenseCategory>> saveCategory(
    ExpenseCategory category,
  ) async {
    return AppSuccess(category);
  }

  @override
  Future<AppResult<void>> deleteCategory(String categoryId) async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<OperatingExpense>> saveExpense(
    OperatingExpense expense,
  ) async {
    return saveResult ?? AppSuccess(expense);
  }
}

final class AuditLogRepositoryFake implements IAuditLogRepository {
  final List<AuditLogEntry> entries = [];

  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return AppSuccess(entries);
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    entries.add(entry);
    return AppSuccess(entry);
  }
}
