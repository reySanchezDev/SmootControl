import 'package:equatable/equatable.dart';

/// One daily sales/profit row.
final class DailySalesReportRow extends Equatable {
  /// Creates one daily sales row.
  const DailySalesReportRow({
    required this.date,
    required this.totalCostInCents,
    required this.totalSalesInCents,
  });

  /// Business day represented by this row.
  final DateTime date;

  /// Total sold amount in minor currency units.
  final int totalSalesInCents;

  /// Total historical product cost in minor currency units.
  final int totalCostInCents;

  /// Gross profit before expenses.
  int get grossProfitInCents => totalSalesInCents - totalCostInCents;

  @override
  List<Object?> get props => [date, totalSalesInCents, totalCostInCents];
}

/// Daily sales report for a date range.
final class DailySalesReport extends Equatable {
  /// Creates a daily sales report.
  const DailySalesReport({
    required this.from,
    required this.rows,
    required this.to,
  });

  /// Inclusive start date.
  final DateTime from;

  /// Inclusive end date selected by the user.
  final DateTime to;

  /// Rows grouped by business date.
  final List<DailySalesReportRow> rows;

  /// Total sold amount.
  int get totalSalesInCents =>
      rows.fold(0, (total, row) => total + row.totalSalesInCents);

  /// Total product cost.
  int get totalCostInCents =>
      rows.fold(0, (total, row) => total + row.totalCostInCents);

  /// Total gross profit.
  int get grossProfitInCents => totalSalesInCents - totalCostInCents;

  @override
  List<Object?> get props => [from, to, rows];
}
