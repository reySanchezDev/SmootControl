import 'package:flutter/material.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/presentation/widgets/expenses_backoffice_table.dart';

/// Shares the same selection and toolbar in desktop and compact Backoffice.
class ExpensesOverviewList extends StatelessWidget {
  /// Creates the administrative categories list.
  const ExpensesOverviewList({
    required this.categories,
    required this.onCategoryDelete,
    required this.onCategoryEdit,
    required this.onCreate,
    super.key,
  });

  /// Categories with real hierarchy and business state.
  final List<ExpenseCategory> categories;

  /// Existing category delete action.
  final ValueChanged<ExpenseCategory> onCategoryDelete;

  /// Existing category edit action.
  final ValueChanged<ExpenseCategory> onCategoryEdit;

  /// Creates a new category.
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ExpensesBackofficeTable(
      categories: categories,
      onEdit: onCategoryEdit,
      onDelete: onCategoryDelete,
      onCreate: onCreate,
    );
  }
}
