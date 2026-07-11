part of 'supabase_report_summary_service.dart';

extension _SupabaseReportSummaryMappers on SupabaseReportSummaryService {
  List<ExpenseReportEntry> _expenseDetails(
    List<_RemoteExpense> expenses,
    Map<String, String> categories,
  ) {
    return expenses.map((expense) {
      return ExpenseReportEntry(
        id: expense.id,
        categoryId: expense.categoryId,
        categoryName: categories[expense.categoryId] ?? 'Sin categoria',
        amountInCents: expense.amountInCents,
        description: expense.description,
        createdAt: expense.createdAt,
        createdBy: expense.createdBy,
      );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ProductSalesMetric> _rankProducts(List<_RemoteSaleItem> items) {
    final metrics = <String, ProductSalesMetric>{};

    for (final item in items) {
      final current = metrics[item.productId];
      metrics[item.productId] = ProductSalesMetric(
        productId: item.productId,
        productName: item.productName,
        quantity: (current?.quantity ?? 0) + item.quantity,
        salesInCents: (current?.salesInCents ?? 0) + item.totalInCents,
        profitInCents:
            (current?.profitInCents ?? 0) +
            item.totalInCents -
            item.totalCostInCents,
      );
    }

    return metrics.values.toList()..sort((a, b) {
      final quantityComparison = b.quantity.compareTo(a.quantity);
      if (quantityComparison != 0) return quantityComparison;
      return b.salesInCents.compareTo(a.salesInCents);
    });
  }
}
