import 'package:equatable/equatable.dart';

/// Category used to classify operational expenses.
final class ExpenseCategory extends Equatable {
  /// Creates an expense category.
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.isActive,
    this.parentId,
  });

  /// Unique category identifier.
  final String id;

  /// Visible category name.
  final String name;

  /// Parent category identifier when this category belongs to one group.
  final String? parentId;

  /// Whether the category is available for new expenses.
  final bool isActive;

  @override
  List<Object?> get props => [id, name, parentId, isActive];
}
