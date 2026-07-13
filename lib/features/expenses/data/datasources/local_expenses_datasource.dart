import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/expenses/data/models/expense_category_model.dart';
import 'package:smoo_control/features/expenses/data/models/operating_expense_model.dart';

/// Local datasource for operational expenses.
final class LocalExpensesDataSource {
  /// Creates a local expenses datasource.
  const LocalExpensesDataSource(this._database);

  final AppDatabase _database;

  /// Returns local expense categories.
  Future<List<ExpenseCategoryModel>> getCategories() async {
    final query = _database.select(_database.localExpenseCategories)
      ..orderBy([(category) => OrderingTerm.asc(category.name)]);
    final rows = await query.get();

    return rows.map(ExpenseCategoryModel.fromLocal).toList();
  }

  /// Returns local expenses created inside the requested date range.
  Future<List<OperatingExpenseModel>> getExpenses({
    required DateTime from,
    required DateTime to,
  }) async {
    final query = _database.select(_database.localOperatingExpenses)
      ..where((expense) {
        return expense.createdAt.isBiggerOrEqualValue(from) &
            expense.createdAt.isSmallerThanValue(to);
      })
      ..orderBy([(expense) => OrderingTerm.desc(expense.createdAt)]);
    final rows = await query.get();

    return rows.map(OperatingExpenseModel.fromLocal).toList();
  }

  /// Inserts or updates a local expense category.
  Future<ExpenseCategoryModel> saveCategory(
    ExpenseCategoryModel category,
  ) async {
    final now = DateTime.now();

    await _database
        .into(_database.localExpenseCategories)
        .insertOnConflictUpdate(
          LocalExpenseCategoriesCompanion(
            id: Value(category.id),
            name: Value(category.name),
            parentId: Value(category.parentId),
            isActive: Value(category.isActive),
            includeInGrossProfitCoverage: Value(
              category.includeInGrossProfitCoverage,
            ),
            coverageExpenseType: Value(category.coverageType?.name),
            coverageEstimatedAmountInCents: Value(
              category.coverageEstimatedAmountInCents,
            ),
            coverageFrequency: Value(category.coverageFrequency?.name),
            coverageDueDaysJson: Value(category.coverageDueDaysJson),
            coverageNotes: Value(category.coverageNotes),
            coverageIsActive: Value(category.coverageIsActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return category;
  }

  /// Deletes a local expense category and moves direct children to root.
  Future<void> deleteCategory(String categoryId) async {
    await _database.transaction(() async {
      await (_database.update(
        _database.localExpenseCategories,
      )..where((category) => category.parentId.equals(categoryId))).write(
        const LocalExpenseCategoriesCompanion(parentId: Value(null)),
      );
      await (_database.delete(
        _database.localExpenseCategories,
      )..where((category) => category.id.equals(categoryId))).go();
    });
  }

  /// Inserts or updates a local operational expense.
  Future<OperatingExpenseModel> saveExpense(
    OperatingExpenseModel expense,
  ) async {
    final now = DateTime.now();

    await _database
        .into(_database.localOperatingExpenses)
        .insertOnConflictUpdate(
          LocalOperatingExpensesCompanion(
            id: Value(expense.id),
            categoryId: Value(expense.categoryId),
            cashRegisterSessionId: Value(expense.cashRegisterSessionId),
            expenseKind: Value(expense.kindValue),
            employeeId: Value(expense.employeeId),
            affectsCash: Value(expense.affectsCash),
            amountInCents: Value(expense.amountInCents),
            description: Value(expense.description),
            createdBy: Value(expense.createdBy),
            createdAt: Value(expense.createdAt),
            updatedAt: Value(now),
          ),
        );

    return expense;
  }
}
