import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';

/// Base event for expenses state management.
sealed class ExpensesEvent extends Equatable {
  /// Creates an expenses event.
  const ExpensesEvent();

  @override
  List<Object?> get props => [];
}

/// Loads expense categories.
final class ExpenseCategoriesLoadRequested extends ExpensesEvent {
  /// Creates a categories load event.
  const ExpenseCategoriesLoadRequested();
}

/// Saves an expense category.
final class ExpenseCategorySaved extends ExpensesEvent {
  /// Creates an expense category save event.
  const ExpenseCategorySaved(this.category);

  /// Category to persist.
  final ExpenseCategory category;

  @override
  List<Object?> get props => [category];
}

/// Deletes an expense category.
final class ExpenseCategoryDeleted extends ExpensesEvent {
  /// Creates an expense category delete event.
  const ExpenseCategoryDeleted(this.category);

  /// Category to delete.
  final ExpenseCategory category;

  @override
  List<Object?> get props => [category];
}

/// Saves an operational expense.
final class ExpenseSaved extends ExpensesEvent {
  /// Creates an expense save event.
  const ExpenseSaved(this.expense);

  /// Expense to persist.
  final OperatingExpense expense;

  @override
  List<Object?> get props => [expense];
}
