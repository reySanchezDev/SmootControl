import 'package:equatable/equatable.dart';

/// Cash closing report for one inclusive date range.
final class CashClosingReport extends Equatable {
  /// Creates a cash closing report.
  const CashClosingReport({
    required this.from,
    required this.generatedAt,
    required this.sessions,
    required this.to,
  });

  /// Inclusive start date.
  final DateTime from;

  /// Inclusive end date.
  final DateTime to;

  /// Report generation timestamp.
  final DateTime generatedAt;

  /// Cash register sessions in the period.
  final List<CashClosingSessionReport> sessions;

  /// Total opening cash.
  int get openingCashInCents => _sum((session) => session.openingCashInCents);

  /// Total cash sales.
  int get cashSalesInCents => _sum((session) => session.cashSalesInCents);

  /// Total transfer sales.
  int get transferSalesInCents =>
      _sum((session) => session.transferSalesInCents);

  /// Other non-cash sales.
  int get otherSalesInCents => _sum((session) => session.otherSalesInCents);

  /// Global sales across all payment methods.
  int get totalSalesInCents => _sum((session) => session.totalSalesInCents);

  /// Cash expenses paid from POS cash drawer.
  int get cashExpensesInCents => _sum((session) => session.cashExpensesInCents);

  /// Expected cash after cash sales and cash expenses.
  int get expectedCashInCents => _sum((session) => session.expectedCashInCents);

  /// Counted physical cash for closed sessions.
  int get physicalCashInCents => _sum((session) => session.physicalCashInCents);

  /// Difference between physical and expected cash.
  int get differenceInCents => sessions
      .where((session) => session.hasPhysicalCount)
      .fold(0, (total, session) => total + session.differenceInCents);

  /// Whether at least one session still has no physical count.
  bool get hasPendingPhysicalCount =>
      sessions.any((session) => !session.hasPhysicalCount);

  /// Number of sales.
  int get saleCount => _sum((session) => session.saleCount);

  /// Number of cash expenses.
  int get expenseCount => _sum((session) => session.expenseCount);

  int _sum(int Function(CashClosingSessionReport session) value) {
    return sessions.fold(0, (total, session) => total + value(session));
  }

  @override
  List<Object?> get props => [from, to, generatedAt, sessions];
}

/// Cash closing numbers for one register session.
final class CashClosingSessionReport extends Equatable {
  /// Creates one cash session report row.
  const CashClosingSessionReport({
    required this.businessDate,
    required this.cashExpenses,
    required this.cashierName,
    required this.deviceName,
    required this.hasPhysicalCount,
    required this.id,
    required this.methodTotals,
    required this.openingCashInCents,
    required this.physicalCashInCents,
    required this.saleCount,
    required this.status,
  });

  /// Remote cash register session id.
  final String id;

  /// Business date.
  final DateTime businessDate;

  /// Cashier display name.
  final String cashierName;

  /// POS device display name.
  final String deviceName;

  /// Open/closed status.
  final String status;

  /// Whether the drawer has a declared physical count.
  final bool hasPhysicalCount;

  /// Opening cash amount.
  final int openingCashInCents;

  /// Counted physical cash, if available.
  final int physicalCashInCents;

  /// Number of completed sales.
  final int saleCount;

  /// Sales grouped by payment method.
  final List<CashClosingMethodTotal> methodTotals;

  /// POS expenses tied to this cash session and affecting cash.
  final List<CashClosingExpenseLine> cashExpenses;

  /// Cash sales only.
  int get cashSalesInCents => methodTotals
      .where((method) => method.affectsCash)
      .fold(0, (total, method) => total + method.amountInCents);

  /// Transfer sales.
  int get transferSalesInCents => methodTotals
      .where((method) => method.isTransfer)
      .fold(0, (total, method) => total + method.amountInCents);

  /// Sales that are neither cash nor transfer.
  int get otherSalesInCents => methodTotals
      .where((method) => !method.affectsCash && !method.isTransfer)
      .fold(0, (total, method) => total + method.amountInCents);

  /// Total sales.
  int get totalSalesInCents =>
      methodTotals.fold(0, (total, method) => total + method.amountInCents);

  /// Expenses paid with drawer cash.
  int get cashExpensesInCents =>
      cashExpenses.fold(0, (total, expense) => total + expense.amountInCents);

  /// Expected drawer cash.
  int get expectedCashInCents =>
      openingCashInCents + cashSalesInCents - cashExpensesInCents;

  /// Physical minus expected.
  int get differenceInCents =>
      hasPhysicalCount ? physicalCashInCents - expectedCashInCents : 0;

  /// Number of cash expense lines.
  int get expenseCount => cashExpenses.length;

  @override
  List<Object?> get props => [
    id,
    businessDate,
    cashierName,
    deviceName,
    status,
    hasPhysicalCount,
    openingCashInCents,
    physicalCashInCents,
    saleCount,
    methodTotals,
    cashExpenses,
  ];
}

/// Total for one payment method.
final class CashClosingMethodTotal extends Equatable {
  /// Creates a payment method total.
  const CashClosingMethodTotal({
    required this.affectsCash,
    required this.amountInCents,
    required this.groupName,
    required this.isTransfer,
    required this.name,
  });

  /// Method name.
  final String name;

  /// Navigation/payment group name.
  final String groupName;

  /// Whether it affects cash drawer.
  final bool affectsCash;

  /// Whether it belongs to transfer payments.
  final bool isTransfer;

  /// Total amount.
  final int amountInCents;

  @override
  List<Object?> get props => [
    name,
    groupName,
    affectsCash,
    isTransfer,
    amountInCents,
  ];
}

/// One POS cash expense in a closing report.
final class CashClosingExpenseLine extends Equatable {
  /// Creates one cash expense line.
  const CashClosingExpenseLine({
    required this.amountInCents,
    required this.categoryName,
    required this.description,
    required this.spentAt,
  });

  /// Expense date.
  final DateTime spentAt;

  /// Expense category.
  final String categoryName;

  /// Description.
  final String description;

  /// Amount paid.
  final int amountInCents;

  @override
  List<Object?> get props => [
    spentAt,
    categoryName,
    description,
    amountInCents,
  ];
}
