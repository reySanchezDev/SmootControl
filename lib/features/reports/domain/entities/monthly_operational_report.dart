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

/// Coverage obligation configured from an expense subcategory.
final class MonthlyOperationalCoverageRow extends Equatable {
  /// Creates one coverage obligation row.
  const MonthlyOperationalCoverageRow({
    required this.actualInCents,
    required this.categoryName,
    required this.dueDays,
    required this.frequencyLabel,
    required this.projectedInCents,
    required this.typeLabel,
  });

  /// Visible expense category path.
  final String categoryName;

  /// Fixed or variable label.
  final String typeLabel;

  /// Frequency label.
  final String frequencyLabel;

  /// Configured payment days.
  final List<int> dueDays;

  /// Projected amount for the selected period.
  final int projectedInCents;

  /// Actual expenses already registered in the selected period.
  final int actualInCents;

  /// Amount still needing coverage.
  int get pendingInCents {
    final pending = projectedInCents - actualInCents;
    return pending < 0 ? 0 : pending;
  }

  /// Amount used to measure coverage.
  int get obligationInCents {
    return actualInCents > projectedInCents ? actualInCents : projectedInCents;
  }

  @override
  List<Object?> get props => [
    categoryName,
    typeLabel,
    frequencyLabel,
    dueDays,
    projectedInCents,
    actualInCents,
  ];
}

/// Internal cut used to follow the month by payroll-friendly periods.
final class MonthlyOperationalPeriodCut extends Equatable {
  /// Creates one operational period cut.
  const MonthlyOperationalPeriodCut({
    required this.from,
    required this.grossProfitInCents,
    required this.labelKey,
    required this.obligationInCents,
    required this.pendingDisbursementInCents,
    required this.to,
  });

  /// Stable label key resolved by the UI.
  final String labelKey;

  /// Inclusive start date.
  final DateTime from;

  /// Inclusive end date.
  final DateTime to;

  /// Gross profit generated in the cut.
  final int grossProfitInCents;

  /// Obligations expected in the cut.
  final int obligationInCents;

  /// Cash still expected to be delivered for the cut.
  final int pendingDisbursementInCents;

  /// Estimated surplus or missing amount after obligations.
  int get balanceInCents => grossProfitInCents - obligationInCents;

  /// Portion of obligations covered by gross profit.
  double get coveragePercent {
    if (obligationInCents <= 0) return 100;
    return grossProfitInCents / obligationInCents * 100;
  }

  /// True when the cut already covers expected obligations.
  bool get isCovered => balanceInCents >= 0;

  @override
  List<Object?> get props => [
    labelKey,
    from,
    to,
    grossProfitInCents,
    obligationInCents,
    pendingDisbursementInCents,
  ];
}

/// Monthly comparison between sales, expenses and payroll.
final class MonthlyOperationalReport extends Equatable {
  /// Creates an operational monthly report.
  const MonthlyOperationalReport({
    required this.advancesDeliveredInCents,
    required this.consideredExpensesByCategory,
    required this.coverageRows,
    required this.dailyRows,
    required this.excludedExpensesInCents,
    required this.from,
    required this.payrollBalanceInCents,
    required this.payrollNetInCents,
    required this.payrollPaidInCents,
    required this.pendingStaffConsumptionInCents,
    required this.periodCuts,
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

  /// Configured coverage indicators.
  final List<MonthlyOperationalCoverageRow> coverageRows;

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

  /// Internal cuts, normally first and second fortnight.
  final List<MonthlyOperationalPeriodCut> periodCuts;

  /// Gross profit before expenses and payroll.
  int get grossProfitInCents => totalSalesInCents - totalCostInCents;

  /// Considered expenses total.
  int get consideredExpensesInCents {
    return consideredExpensesByCategory.fold(
      0,
      (total, row) => total + row.totalInCents,
    );
  }

  /// Total configured coverage target for the selected period.
  int get projectedCoverageInCents {
    return coverageRows.fold(
      0,
      (total, row) => total + row.projectedInCents,
    );
  }

  /// Total already spent in configured coverage categories.
  int get actualCoverageInCents {
    return coverageRows.fold(0, (total, row) => total + row.actualInCents);
  }

  /// Coverage obligation used for decision indicators.
  int get coverageObligationInCents {
    return coverageRows.fold(
      0,
      (total, row) => total + row.obligationInCents,
    );
  }

  /// Total obligations expected for the selected period.
  int get monthlyObligationInCents =>
      coverageObligationInCents + payrollNetInCents;

  /// Money still expected to be delivered for payroll and expenses.
  int get pendingDisbursementInCents {
    final pendingCoverage = coverageRows.fold(
      0,
      (total, row) => total + row.pendingInCents,
    );
    return payrollBalanceInCents + pendingCoverage;
  }

  /// Estimated surplus or missing amount after obligations.
  int get monthlyBalanceInCents =>
      grossProfitInCents - monthlyObligationInCents;

  /// Gross profit after expenses and payroll commitment.
  int get operationalResultInCents => monthlyBalanceInCents;

  /// Percentage of obligations covered by gross profit.
  double get coveragePercent {
    if (monthlyObligationInCents <= 0) return 100;
    return grossProfitInCents / monthlyObligationInCents * 100;
  }

  /// True when gross profit does not cover expenses plus payroll.
  bool get hasCoverageRisk => monthlyBalanceInCents < 0;

  @override
  List<Object?> get props => [
    from,
    to,
    totalSalesInCents,
    totalCostInCents,
    consideredExpensesByCategory,
    coverageRows,
    excludedExpensesInCents,
    payrollNetInCents,
    payrollPaidInCents,
    payrollBalanceInCents,
    advancesDeliveredInCents,
    pendingStaffConsumptionInCents,
    dailyRows,
    periodCuts,
  ];
}
