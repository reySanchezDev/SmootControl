part of 'supabase_monthly_operational_report_service.dart';

final class _DailyAccumulator {
  int cost = 0;
  int expenses = 0;
  int sales = 0;
}

final class _ExpenseCategory {
  const _ExpenseCategory({
    required this.id,
    required this.includeInCoverage,
    required this.name,
    this.parentId,
  });

  final String id;
  final bool includeInCoverage;
  final String name;
  final String? parentId;
}

final class _PayrollTotals {
  const _PayrollTotals({this.balance = 0, this.net = 0, this.paid = 0});

  final int balance;
  final int net;
  final int paid;
}

final class _RemoteExpense {
  const _RemoteExpense({
    required this.amountInCents,
    required this.categoryId,
    required this.date,
  });

  final int amountInCents;
  final String categoryId;
  final DateTime date;
}

final class _RemoteSale {
  const _RemoteSale({
    required this.date,
    required this.id,
    required this.totalInCents,
  });

  final DateTime date;
  final String id;
  final int totalInCents;
}

final class _RemoteSaleItem {
  const _RemoteSaleItem({required this.costInCents, required this.saleId});

  final int costInCents;
  final String saleId;
}
