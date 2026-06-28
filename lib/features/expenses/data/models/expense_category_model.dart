import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';

/// Data model for expense categories.
final class ExpenseCategoryModel extends Equatable {
  /// Creates an expense category model.
  const ExpenseCategoryModel({
    required this.id,
    required this.name,
    required this.isActive,
    this.parentId,
  });

  /// Creates a model from a local Drift row.
  factory ExpenseCategoryModel.fromLocal(LocalExpenseCategory row) {
    return ExpenseCategoryModel(
      id: row.id,
      name: row.name,
      parentId: row.parentId,
      isActive: row.isActive,
    );
  }

  /// Creates a model from a domain entity.
  factory ExpenseCategoryModel.fromEntity(ExpenseCategory entity) {
    return ExpenseCategoryModel(
      id: entity.id,
      name: entity.name,
      parentId: entity.parentId,
      isActive: entity.isActive,
    );
  }

  /// Unique category identifier.
  final String id;

  /// Visible category name.
  final String name;

  /// Parent category identifier.
  final String? parentId;

  /// Whether the category can be used.
  final bool isActive;

  /// Converts this model to a domain entity.
  ExpenseCategory toEntity() {
    return ExpenseCategory(
      id: id,
      name: name,
      parentId: parentId,
      isActive: isActive,
    );
  }

  @override
  List<Object?> get props => [id, name, parentId, isActive];
}
