import 'package:equatable/equatable.dart';

/// Business meaning of an operating expense row.
enum OperatingExpenseKind {
  /// Regular operational expense.
  operational,

  /// Salary advance registered from POS.
  salaryAdvance,
}

/// Operational expense paid from the business or cash register.
final class OperatingExpense extends Equatable {
  /// Creates an operating expense.
  const OperatingExpense({
    required this.id,
    required this.categoryId,
    required this.amountInCents,
    required this.description,
    required this.createdAt,
    required this.createdBy,
    this.kind = OperatingExpenseKind.operational,
    this.cashRegisterSessionId,
    this.employeeId,
    this.affectsCash = true,
  });

  /// Unique expense identifier.
  final String id;

  /// Expense category identifier.
  final String categoryId;

  /// Cash register session when paid from the register.
  final String? cashRegisterSessionId;

  /// Business meaning of the expense.
  final OperatingExpenseKind kind;

  /// Employee linked to a salary advance.
  final String? employeeId;

  /// Whether this row reduced the POS cash drawer.
  final bool affectsCash;

  /// Expense amount.
  final int amountInCents;

  /// Expense description.
  final String description;

  /// User that registered the expense.
  final String createdBy;

  /// Registration date.
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    categoryId,
    cashRegisterSessionId,
    kind,
    employeeId,
    affectsCash,
    amountInCents,
    description,
    createdBy,
    createdAt,
  ];
}
