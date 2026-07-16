part of 'supabase_product_performance_report_service.dart';

final class _PerformanceAverages {
  const _PerformanceAverages({
    required this.margin,
    required this.profit,
    required this.quantity,
  });

  factory _PerformanceAverages.from(Iterable<ProductPerformanceRow> rows) {
    final list = rows.toList();
    if (list.isEmpty) {
      return const _PerformanceAverages(margin: 0, profit: 0, quantity: 0);
    }
    return _PerformanceAverages(
      margin:
          list.fold<double>(0, (sum, row) => sum + row.margin) / list.length,
      profit:
          list.fold<int>(0, (sum, row) => sum + row.grossProfitInCents) ~/
          list.length,
      quantity:
          list.fold<double>(0, (sum, row) => sum + row.quantitySold) /
          list.length,
    );
  }

  final double margin;
  final int profit;
  final double quantity;
}
