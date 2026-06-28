import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/expenses/domain/entities/expense_category.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';

/// Contract for operational expense persistence.
abstract interface class IExpensesRepository {
  /// Returns configured expense categories.
  Future<AppResult<List<ExpenseCategory>>> getCategories();

  /// Returns operational expenses between two dates.
  Future<AppResult<List<OperatingExpense>>> getExpenses({
    required DateTime from,
    required DateTime to,
  });

  /// Saves an expense category.
  Future<AppResult<ExpenseCategory>> saveCategory(ExpenseCategory category);

  /// Deletes an expense category.
  Future<AppResult<void>> deleteCategory(String categoryId);

  /// Saves an operational expense.
  Future<AppResult<OperatingExpense>> saveExpense(
    OperatingExpense expense,
  );
}
