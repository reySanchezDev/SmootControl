import 'package:equatable/equatable.dart';

/// One raw material currently below zero.
final class NegativeInventoryRow extends Equatable {
  /// Creates one negative inventory row.
  const NegativeInventoryRow({
    required this.categoryName,
    required this.costInCents,
    required this.lastMovementAt,
    required this.lastReferenceId,
    required this.productId,
    required this.productName,
    required this.quantityOnHand,
  });

  /// Product identifier.
  final String productId;

  /// Raw material name.
  final String productName;

  /// Category path.
  final String categoryName;

  /// Current negative stock.
  final int quantityOnHand;

  /// Unit cost in minor currency units.
  final int costInCents;

  /// Last recipe movement timestamp, when available.
  final DateTime? lastMovementAt;

  /// Sale or staff consumption that generated the last movement.
  final String? lastReferenceId;

  /// Quantity required to bring the item back to zero.
  int get quantityToRegularize => quantityOnHand.abs();

  /// Estimated cost to regularize this negative stock.
  int get regularizationCostInCents => quantityToRegularize * costInCents;

  @override
  List<Object?> get props => [
    productId,
    productName,
    categoryName,
    quantityOnHand,
    costInCents,
    lastMovementAt,
    lastReferenceId,
  ];
}

/// Snapshot of raw materials with negative inventory.
final class NegativeInventoryReport extends Equatable {
  /// Creates a negative inventory report.
  const NegativeInventoryReport({
    required this.generatedAt,
    required this.rows,
  });

  /// Snapshot timestamp.
  final DateTime generatedAt;

  /// Negative rows.
  final List<NegativeInventoryRow> rows;

  /// Total estimated cost to bring all negatives back to zero.
  int get regularizationCostInCents {
    return rows.fold(0, (total, row) => total + row.regularizationCostInCents);
  }

  /// Count of raw materials below zero.
  int get productCount => rows.length;

  @override
  List<Object?> get props => [generatedAt, rows];
}
