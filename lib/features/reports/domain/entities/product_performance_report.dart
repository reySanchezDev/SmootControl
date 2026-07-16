import 'package:equatable/equatable.dart';

/// Product sales and profitability report for a date range.
final class ProductPerformanceReport extends Equatable {
  /// Creates the report.
  const ProductPerformanceReport({
    required this.from,
    required this.to,
    required this.rows,
  });

  /// Inclusive start date.
  final DateTime from;

  /// Inclusive end date.
  final DateTime to;

  /// Product rows sorted by business relevance.
  final List<ProductPerformanceRow> rows;

  /// Total sales amount.
  int get totalSalesInCents =>
      rows.fold(0, (sum, row) => sum + row.salesInCents);

  /// Total historical cost.
  int get totalCostInCents => rows.fold(0, (sum, row) => sum + row.costInCents);

  /// Total gross profit.
  int get grossProfitInCents =>
      rows.fold(0, (sum, row) => sum + row.grossProfitInCents);

  /// Best-selling product by units.
  ProductPerformanceRow? get bestSeller => rows.isEmpty
      ? null
      : rows.reduce((a, b) => a.quantitySold >= b.quantitySold ? a : b);

  /// Most profitable product by gross profit.
  ProductPerformanceRow? get mostProfitable => rows.isEmpty
      ? null
      : rows.reduce((a, b) {
          return a.grossProfitInCents >= b.grossProfitInCents ? a : b;
        });

  /// Product with the highest margin and at least one sale.
  ProductPerformanceRow? get bestMargin {
    final sold = rows.where((row) => row.salesInCents > 0).toList();
    if (sold.isEmpty) return null;
    return sold.reduce((a, b) => a.margin >= b.margin ? a : b);
  }

  @override
  List<Object?> get props => [from, to, rows];
}

/// Product profitability row.
final class ProductPerformanceRow extends Equatable {
  /// Creates one product row.
  const ProductPerformanceRow({
    required this.categoryName,
    required this.costInCents,
    required this.grossProfitInCents,
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.salesInCents,
    required this.segment,
  });

  /// Product identifier, or a generated key for historical rows without id.
  final String productId;

  /// Product display name.
  final String productName;

  /// Category captured in the sale item.
  final String categoryName;

  /// Units sold.
  final double quantitySold;

  /// Total sales amount.
  final int salesInCents;

  /// Total historical cost.
  final int costInCents;

  /// Total gross profit.
  final int grossProfitInCents;

  /// Decision segment: estrella, oportunidad, volumen or revisar.
  final String segment;

  /// Profit margin from sales.
  double get margin =>
      salesInCents == 0 ? 0 : grossProfitInCents / salesInCents;

  /// Returns a copy with a different decision segment.
  ProductPerformanceRow copyWith({String? segment}) {
    return ProductPerformanceRow(
      categoryName: categoryName,
      costInCents: costInCents,
      grossProfitInCents: grossProfitInCents,
      productId: productId,
      productName: productName,
      quantitySold: quantitySold,
      salesInCents: salesInCents,
      segment: segment ?? this.segment,
    );
  }

  @override
  List<Object?> get props => [
    productId,
    productName,
    categoryName,
    quantitySold,
    salesInCents,
    costInCents,
    grossProfitInCents,
    segment,
  ];
}
