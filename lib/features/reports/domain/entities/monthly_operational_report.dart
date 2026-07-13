import 'package:equatable/equatable.dart';

/// One day in the operational monthly comparison.
final class MonthlyOperationalDailyRow extends Equatable {
  /// Creates one daily operational row.
  const MonthlyOperationalDailyRow({
    required this.date,
    required this.expensesInCents,
    required this.grossProfitInCents,
    required this.salesInCents,
  });

  /// Day represented by the row.
  final DateTime date;

  /// Completed normal sales for the day.
  final int salesInCents;

  /// Sales minus product cost for the day.
  final int grossProfitInCents;

  /// Operational expenses considered for the day.
  final int expensesInCents;

  /// Gross profit after considered operational expenses.
  int get resultInCents => grossProfitInCents - expensesInCents;

  @override
  List<Object?> get props => [
    date,
    salesInCents,
    grossProfitInCents,
    expensesInCents,
  ];
}

/// Expense category contribution in the operational comparison.
final class MonthlyOperationalExpenseRow extends Equatable {
  /// Creates one expense category row.
  const MonthlyOperationalExpenseRow({
    required this.categoryName,
    required this.totalInCents,
  });

  /// Visible expense category name.
  final String categoryName;

  /// Total amount for the category.
  final int totalInCents;

  @override
  List<Object?> get props => [categoryName, totalInCents];
}

/// Monthly comparison between sales, expenses and payroll.
final class MonthlyOperationalReport extends Equatable {
  /// Creates an operational monthly report.
  const MonthlyOperationalReport({
    required this.advancesDeliveredInCents,
    required this.consideredExpensesByCategory,
    required this.dailyRows,
    required this.excludedExpensesInCents,
    required this.from,
    required this.payrollBalanceInCents,
    required this.payrollNetInCents,
    required this.payrollPaidInCents,
    required this.pendingStaffConsumptionInCents,
    required this.totalCostInCents,
    required this.totalSalesInCents,
    required this.to,
  });

  /// Inclusive start date.
  final DateTime from;

  /// Inclusive end date.
  final DateTime to;

  /// Total completed normal sales.
  final int totalSalesInCents;

  /// Historical product cost of sold items.
  final int totalCostInCents;

  /// Expenses that are configured to affect operational coverage.
  final List<MonthlyOperationalExpenseRow> consideredExpensesByCategory;

  /// Operational expenses intentionally excluded to avoid double counting.
  final int excludedExpensesInCents;

  /// Payroll net amount generated for periods overlapping the range.
  final int payrollNetInCents;

  /// Payroll already paid.
  final int payrollPaidInCents;

  /// Payroll still pending.
  final int payrollBalanceInCents;

  /// Salary advances delivered in the selected range.
  final int advancesDeliveredInCents;

  /// Staff consumptions not assigned to payroll yet.
  final int pendingStaffConsumptionInCents;

  /// Daily comparison rows.
  final List<MonthlyOperationalDailyRow> dailyRows;

  /// Gross profit before expenses and payroll.
  int get grossProfitInCents => totalSalesInCents - totalCostInCents;

  /// Considered expenses total.
  int get consideredExpensesInCents {
    return consideredExpensesByCategory.fold(
      0,
      (total, row) => total + row.totalInCents,
    );
  }

  /// Gross profit after expenses and payroll commitment.
  int get operationalResultInCents {
    return grossProfitInCents - consideredExpensesInCents - payrollNetInCents;
  }

  /// Percentage of gross profit already consumed by expenses and payroll.
  double get coveragePercent {
    if (grossProfitInCents <= 0) return 0;
    final obligations = consideredExpensesInCents + payrollNetInCents;
    return obligations / grossProfitInCents * 100;
  }

  /// True when gross profit does not cover expenses plus payroll.
  bool get hasCoverageRisk => operationalResultInCents < 0;

  @override
  List<Object?> get props => [
    from,
    to,
    totalSalesInCents,
    totalCostInCents,
    consideredExpensesByCategory,
    excludedExpensesInCents,
    payrollNetInCents,
    payrollPaidInCents,
    payrollBalanceInCents,
    advancesDeliveredInCents,
    pendingStaffConsumptionInCents,
    dailyRows,
  ];
}
