import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';

/// Expense row shown in the dedicated expenses report.
final class ExpenseReportEntry extends Equatable {
  /// Creates one expense report row.
  const ExpenseReportEntry({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amountInCents,
    required this.description,
    required this.createdAt,
    required this.createdBy,
  });

  /// Expense identifier.
  final String id;

  /// Category identifier.
  final String categoryId;

  /// Visible category name.
  final String categoryName;

  /// Amount in local currency cents.
  final int amountInCents;

  /// Expense description.
  final String description;

  /// Date and time when the expense was registered.
  final DateTime createdAt;

  /// User that registered the expense.
  final String createdBy;

  @override
  List<Object?> get props => [
    id,
    categoryId,
    categoryName,
    amountInCents,
    description,
    createdAt,
    createdBy,
  ];
}

/// Product performance metric for the selected report period.
final class ProductSalesMetric extends Equatable {
  /// Creates a product sales metric.
  const ProductSalesMetric({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.salesInCents,
    required this.profitInCents,
  });

  /// Product identifier.
  final String productId;

  /// Historical product name.
  final String productName;

  /// Total units sold.
  final int quantity;

  /// Total product sales.
  final int salesInCents;

  /// Estimated product profit before operational expenses.
  final int profitInCents;

  @override
  List<Object?> get props => [
    productId,
    productName,
    quantity,
    salesInCents,
    profitInCents,
  ];
}

/// Business report summary for one period.
final class ReportSummary extends Equatable {
  /// Creates a report summary.
  const ReportSummary({
    required this.from,
    required this.to,
    required this.cashDifferenceInCents,
    required this.cashExpectedInCents,
    required this.cashExpensesInCents,
    required this.cashOpeningInCents,
    required this.cashPhysicalInCents,
    required this.cashSalesInCents,
    required this.cashSessionsCount,
    required this.salesCount,
    required this.voidsCount,
    required this.grossSalesInCents,
    required this.grossProfitInCents,
    required this.expensesInCents,
    required this.expenses,
    required this.netProfitInCents,
    required this.averageTicketInCents,
    required this.topProducts,
    required this.lowestProducts,
    required this.voids,
  });

  /// Inclusive range start.
  final DateTime from;

  /// Exclusive range end.
  final DateTime to;

  /// Number of cash sessions in the selected period.
  final int cashSessionsCount;

  /// Opening cash assigned in the selected period.
  final int cashOpeningInCents;

  /// Cash sales assigned to cash register sessions.
  final int cashSalesInCents;

  /// Expenses assigned to cash register sessions.
  final int cashExpensesInCents;

  /// Expected cash for the selected period.
  final int cashExpectedInCents;

  /// Physical cash counted in closed sessions.
  final int cashPhysicalInCents;

  /// Physical cash minus expected cash for closed sessions.
  final int cashDifferenceInCents;

  /// Number of valid completed sales.
  final int salesCount;

  /// Number of voided sales registered in the period.
  final int voidsCount;

  /// Total sales before expenses.
  final int grossSalesInCents;

  /// Estimated gross profit before expenses.
  final int grossProfitInCents;

  /// Operational expenses registered in the period.
  final int expensesInCents;

  /// Expense rows registered in the selected period.
  final List<ExpenseReportEntry> expenses;

  /// Gross profit minus operational expenses.
  final int netProfitInCents;

  /// Average sale amount.
  final int averageTicketInCents;

  /// Products ordered from most sold to least sold.
  final List<ProductSalesMetric> topProducts;

  /// Products ordered from least sold to most sold.
  final List<ProductSalesMetric> lowestProducts;

  /// Auditable sale voids registered in the selected period.
  final List<SaleVoid> voids;

  @override
  List<Object?> get props => [
    from,
    to,
    cashSessionsCount,
    cashOpeningInCents,
    cashSalesInCents,
    cashExpensesInCents,
    cashExpectedInCents,
    cashPhysicalInCents,
    cashDifferenceInCents,
    salesCount,
    voidsCount,
    grossSalesInCents,
    grossProfitInCents,
    expensesInCents,
    expenses,
    netProfitInCents,
    averageTicketInCents,
    topProducts,
    lowestProducts,
    voids,
  ];
}
