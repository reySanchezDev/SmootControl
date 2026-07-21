import 'package:equatable/equatable.dart';

/// One current inventory valuation row.
final class InventoryValueReportRow extends Equatable {
  /// Creates one inventory valuation row.
  const InventoryValueReportRow({
    required this.categoryName,
    required this.costInCents,
    required this.priceInCents,
    required this.productId,
    required this.productName,
    required this.quantityOnHand,
    this.isRawMaterial = false,
  });

  /// Product identifier.
  final String productId;

  /// Product name.
  final String productName;

  /// Category path or fallback category label.
  final String categoryName;

  /// Current stock.
  final double quantityOnHand;

  /// Current product unit cost in minor currency units.
  final int costInCents;

  /// Current product sale price in minor currency units.
  final int priceInCents;

  /// Whether this row is raw material and not sold directly.
  final bool isRawMaterial;

  /// Capital invested in this product.
  int get inventoryCostInCents => (quantityOnHand * costInCents).round();

  /// Potential revenue if current stock is sold at current price.
  int get potentialSalesInCents {
    if (isRawMaterial) return 0;
    return (quantityOnHand * priceInCents).round();
  }

  /// Potential gross profit before operating expenses.
  int get potentialGrossProfitInCents {
    if (isRawMaterial) return 0;
    return potentialSalesInCents - inventoryCostInCents;
  }

  /// Gross margin percentage over sale price.
  double get marginPercent {
    if (potentialSalesInCents <= 0) return 0;
    return potentialGrossProfitInCents / potentialSalesInCents * 100;
  }

  /// Whether the row needs cost review.
  bool get missingCost => quantityOnHand > 0 && costInCents <= 0;

  /// Whether the row needs price review.
  bool get missingPrice =>
      !isRawMaterial && quantityOnHand > 0 && priceInCents <= 0;

  @override
  List<Object?> get props => [
    productId,
    productName,
    categoryName,
    quantityOnHand,
    costInCents,
    priceInCents,
    isRawMaterial,
  ];
}

/// Inventory value grouped by category.
final class InventoryValueCategoryRow extends Equatable {
  /// Creates one category row.
  const InventoryValueCategoryRow({
    required this.categoryName,
    required this.inventoryCostInCents,
    required this.potentialGrossProfitInCents,
    required this.potentialSalesInCents,
    required this.productCount,
  });

  /// Category path or label.
  final String categoryName;

  /// Products represented by the category.
  final int productCount;

  /// Capital invested in the category.
  final int inventoryCostInCents;

  /// Potential revenue in the category.
  final int potentialSalesInCents;

  /// Potential gross profit in the category.
  final int potentialGrossProfitInCents;

  /// Gross margin percentage over potential sales.
  double get marginPercent {
    if (potentialSalesInCents <= 0) return 0;
    return potentialGrossProfitInCents / potentialSalesInCents * 100;
  }

  @override
  List<Object?> get props => [
    categoryName,
    productCount,
    inventoryCostInCents,
    potentialSalesInCents,
    potentialGrossProfitInCents,
  ];
}

/// Snapshot report for current inventory value.
final class InventoryValueReport extends Equatable {
  /// Creates an inventory value report.
  const InventoryValueReport({
    required this.generatedAt,
    required this.rows,
  });

  /// Timestamp of the snapshot.
  final DateTime generatedAt;

  /// Product rows.
  final List<InventoryValueReportRow> rows;

  /// Total capital invested in stock.
  int get inventoryCostInCents =>
      rows.fold(0, (total, row) => total + row.inventoryCostInCents);

  /// Total potential sale value.
  int get potentialSalesInCents =>
      rows.fold(0, (total, row) => total + row.potentialSalesInCents);

  /// Total potential gross profit.
  int get potentialGrossProfitInCents =>
      rows.fold(0, (total, row) => total + row.potentialGrossProfitInCents);

  /// Gross margin percentage.
  double get marginPercent {
    if (potentialSalesInCents <= 0) return 0;
    return potentialGrossProfitInCents / potentialSalesInCents * 100;
  }

  /// Products with positive stock.
  int get stockedProductCount =>
      rows.where((row) => row.quantityOnHand > 0).length;

  /// Products with stock but no cost.
  int get missingCostCount => rows.where((row) => row.missingCost).length;

  /// Products with stock but no sale price.
  int get missingPriceCount => rows.where((row) => row.missingPrice).length;

  /// Products with low potential margin.
  int get lowMarginCount {
    return rows.where((row) {
      return row.quantityOnHand > 0 &&
          !row.isRawMaterial &&
          row.priceInCents > 0 &&
          row.marginPercent < 20;
    }).length;
  }

  /// Totals grouped by category path.
  List<InventoryValueCategoryRow> get byCategory {
    final accumulators = <String, _InventoryValueAccumulator>{};
    for (final row in rows) {
      accumulators.update(
        row.categoryName,
        (current) {
          current.add(row);
          return current;
        },
        ifAbsent: () => _InventoryValueAccumulator.fromRow(row),
      );
    }

    return accumulators.entries.map((entry) {
      final value = entry.value;
      return InventoryValueCategoryRow(
        categoryName: entry.key,
        inventoryCostInCents: value.inventoryCostInCents,
        potentialGrossProfitInCents: value.potentialGrossProfitInCents,
        potentialSalesInCents: value.potentialSalesInCents,
        productCount: value.productCount,
      );
    }).toList()..sort(
      (a, b) => b.inventoryCostInCents.compareTo(a.inventoryCostInCents),
    );
  }

  @override
  List<Object?> get props => [generatedAt, rows];
}

final class _InventoryValueAccumulator {
  _InventoryValueAccumulator();

  _InventoryValueAccumulator.fromRow(InventoryValueReportRow row) {
    add(row);
  }

  int inventoryCostInCents = 0;
  int potentialGrossProfitInCents = 0;
  int potentialSalesInCents = 0;
  int productCount = 0;

  void add(InventoryValueReportRow row) {
    productCount++;
    inventoryCostInCents += row.inventoryCostInCents;
    potentialSalesInCents += row.potentialSalesInCents;
    potentialGrossProfitInCents += row.potentialGrossProfitInCents;
  }
}
