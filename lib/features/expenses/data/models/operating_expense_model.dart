import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';

/// Data model for operational expenses.
final class OperatingExpenseModel extends Equatable {
  /// Creates an operating expense model.
  const OperatingExpenseModel({
    required this.id,
    required this.categoryId,
    required this.amountInCents,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.cashRegisterSessionId,
  });

  /// Creates a model from a local Drift row.
  factory OperatingExpenseModel.fromLocal(LocalOperatingExpense row) {
    return OperatingExpenseModel(
      id: row.id,
      categoryId: row.categoryId,
      cashRegisterSessionId: row.cashRegisterSessionId,
      amountInCents: row.amountInCents,
      description: row.description,
      createdBy: row.createdBy,
      createdAt: row.createdAt,
    );
  }

  /// Creates a model from a domain entity.
  factory OperatingExpenseModel.fromEntity(OperatingExpense entity) {
    return OperatingExpenseModel(
      id: entity.id,
      categoryId: entity.categoryId,
      cashRegisterSessionId: entity.cashRegisterSessionId,
      amountInCents: entity.amountInCents,
      description: entity.description,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
    );
  }

  /// Unique expense identifier.
  final String id;

  /// Expense category identifier.
  final String categoryId;

  /// Cash register session identifier when paid from cash.
  final String? cashRegisterSessionId;

  /// Expense amount.
  final int amountInCents;

  /// Expense description.
  final String description;

  /// User that registered the expense.
  final String createdBy;

  /// Registration date.
  final DateTime createdAt;

  /// Converts this model to a domain entity.
  OperatingExpense toEntity() {
    return OperatingExpense(
      id: id,
      categoryId: categoryId,
      cashRegisterSessionId: cashRegisterSessionId,
      amountInCents: amountInCents,
      description: description,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

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
