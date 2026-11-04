import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';

/// Base expenses state.
sealed class ExpensesState extends Equatable {
  /// Creates an expenses state.
  const ExpensesState();

  @override
  List<Object?> get props => [];
}

/// Initial expenses state.
final class ExpensesInitial extends ExpensesState {
  /// Creates the initial state.
  const ExpensesInitial();
}

/// Expenses loading state.
final class ExpensesLoading extends ExpensesState {
  /// Creates a loading state.
  const ExpensesLoading();
}

/// Expenses overview loaded state.
final class ExpensesOverviewLoaded extends ExpensesState {
  /// Creates an expenses overview state.
  const ExpensesOverviewLoaded({
    required this.categories,
  });

  /// Available expense categories.
  final List<ExpenseCategory> categories;

  @override
  List<Object?> get props => [categories];
}

/// Expenses failure state.
final class ExpensesFailure extends ExpensesState {
  /// Creates a failure state.
  const ExpensesFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// Confirmed expense action, emitted only after persistence succeeds.
final class ExpensesActionSucceeded extends ExpensesState {
  /// Creates an operation-specific successful outcome.
  const ExpensesActionSucceeded(this.message);

  /// Human-readable operation result.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Failed expense action, distinguished from initial loading failures.
final class ExpensesActionFailed extends ExpensesState {
  /// Creates an operation-specific failure.
  const ExpensesActionFailed(this.failure);

  /// Persistence failure.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
