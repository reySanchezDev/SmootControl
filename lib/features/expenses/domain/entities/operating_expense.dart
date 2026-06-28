import 'package:equatable/equatable.dart';

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
    this.cashRegisterSessionId,
  });

  /// Unique expense identifier.
  final String id;

  /// Expense category identifier.
  final String categoryId;

  /// Cash register session when paid from the register.
  final String? cashRegisterSessionId;

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
    amountInCents,
    description,
    createdBy,
    createdAt,
  ];
}
