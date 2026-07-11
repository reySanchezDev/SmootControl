import 'package:equatable/equatable.dart';

/// One daily expense row.
final class DailyExpensesReportRow extends Equatable {
  /// Creates one daily expense row.
  const DailyExpensesReportRow({
    required this.date,
    required this.totalInCents,
  });

  /// Business day represented by this row.
  final DateTime date;

  /// Total operational expenses in minor currency units.
  final int totalInCents;

  @override
  List<Object?> get props => [date, totalInCents];
}

/// Expense total grouped by category.
final class ExpenseCategoryReportRow extends Equatable {
  /// Creates a category expense row.
  const ExpenseCategoryReportRow({
    required this.categoryId,
    required this.categoryName,
    required this.totalInCents,
  });

  /// Category identifier.
  final String categoryId;

  /// Visible category name.
  final String categoryName;

  /// Total spent in this category.
  final int totalInCents;

  @override
  List<Object?> get props => [categoryId, categoryName, totalInCents];
}

/// Expenses report for a date range.
final class ExpensesReport extends Equatable {
  /// Creates an expenses report.
  const ExpensesReport({
    required this.byCategory,
    required this.from,
    required this.rows,
    required this.to,
  });

  /// Inclusive start date.
  final DateTime from;

  /// Inclusive end date selected by the user.
  final DateTime to;

  /// Daily rows.
  final List<DailyExpensesReportRow> rows;

  /// Category breakdown.
  final List<ExpenseCategoryReportRow> byCategory;

  /// Total expenses.
  int get totalInCents =>
      rows.fold(0, (total, row) => total + row.totalInCents);

  /// Days represented by the selected range.
  int get periodDays => to.difference(from).inDays + 1;

  /// Average expense per selected day.
  int get averageDailyInCents =>
      periodDays <= 0 ? 0 : totalInCents ~/ periodDays;

  /// Highest expense category, when available.
  ExpenseCategoryReportRow? get topCategory =>
      byCategory.isEmpty ? null : byCategory.first;

  @override
  List<Object?> get props => [from, to, rows, byCategory];
}
