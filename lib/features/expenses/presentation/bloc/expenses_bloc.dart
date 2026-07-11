import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/repositories/i_expenses_repository.dart';
import 'package:smoo_control/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:smoo_control/features/expenses/presentation/bloc/expenses_state.dart';
import 'package:uuid/uuid.dart';

/// BLoC for expense category reads and expense creation.
final class ExpensesBloc extends Bloc<ExpensesEvent, ExpensesState> {
  /// Creates an expenses BLoC.
  ExpensesBloc({
    required IExpensesRepository repository,
    required IAuditLogRepository auditLogRepository,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _auditLogRepository = auditLogRepository,
       _uuid = uuid,
       super(const ExpensesInitial()) {
    on<ExpenseCategoriesLoadRequested>(_onCategoriesLoadRequested);
    on<ExpenseCategorySaved>(_onExpenseCategorySaved);
    on<ExpenseCategoryDeleted>(_onExpenseCategoryDeleted);
    on<ExpenseSaved>(_onExpenseSaved);
  }

  final IExpensesRepository _repository;
  final IAuditLogRepository _auditLogRepository;
  final Uuid _uuid;

  Future<void> _onCategoriesLoadRequested(
    ExpenseCategoriesLoadRequested event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(const ExpensesLoading());
    await _emitOverview(emit);
  }

  Future<void> _onExpenseCategorySaved(
    ExpenseCategorySaved event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(const ExpensesLoading());
    final saveResult = await _repository.saveCategory(event.category);

    await saveResult.when(
      success: (_) async {
        await _auditLogRepository.saveEntry(
          AuditLogEntry(
            id: _uuid.v4(),
            action: 'expenses.category.save',
            entityName: 'expense_categories',
            entityId: event.category.id,
            details: {'name': event.category.name},
            occurredAt: DateTime.now(),
          ),
        );
        await _emitOverview(emit);
      },
      failure: (failure) async => emit(ExpensesFailure(failure)),
    );
  }

  Future<void> _onExpenseCategoryDeleted(
    ExpenseCategoryDeleted event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(const ExpensesLoading());
    final deleteResult = await _repository.deleteCategory(event.category.id);

    await deleteResult.when(
      success: (_) async {
        await _auditLogRepository.saveEntry(
          AuditLogEntry(
            id: _uuid.v4(),
            action: 'expenses.category.delete',
            entityName: 'expense_categories',
            entityId: event.category.id,
            details: {'name': event.category.name},
            occurredAt: DateTime.now(),
          ),
        );
        await _emitOverview(emit);
      },
      failure: (failure) async => emit(ExpensesFailure(failure)),
    );
  }

  Future<void> _onExpenseSaved(
    ExpenseSaved event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(const ExpensesLoading());
    final result = await _repository.saveExpense(event.expense);
    await result.when(
      success: (_) async {
        await _auditLogRepository.saveEntry(
          AuditLogEntry(
            id: _uuid.v4(),
            actorUserId: event.expense.createdBy,
            action: 'expenses.save',
            entityName: 'operating_expenses',
            entityId: event.expense.id,
            details: {
              'amountInCents': event.expense.amountInCents,
              'description': event.expense.description,
            },
            occurredAt: DateTime.now(),
          ),
        );
        await _emitOverview(emit);
      },
      failure: (failure) async => emit(ExpensesFailure(failure)),
    );
  }

  Future<void> _emitOverview(Emitter<ExpensesState> emit) async {
    final categoriesResult = await _repository.getCategories();
    final List<ExpenseCategory> categories;
    switch (categoriesResult) {
      case AppSuccess(:final value):
        categories = value;
      case AppFailureResult(:final error):
        emit(ExpensesFailure(error));
        return;
    }

    emit(ExpensesOverviewLoaded(categories: categories));
  }
}
