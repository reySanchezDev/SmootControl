import 'package:equatable/equatable.dart';

/// Inventory movement kind shown by the administrative movement browser.
enum InventoryMovementDocumentType {
  /// Any movement type.
  all,

  /// Stock purchase entries.
  purchase,

  /// Count adjustment documents.
  adjustment,

  /// Stock consumed by sales.
  sale,

  /// Stock returned by sale voids.
  saleVoid,
}

/// Header for one inventory movement document or movement group.
final class InventoryMovementDocument extends Equatable {
  /// Creates an inventory movement header.
  const InventoryMovementDocument({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    required this.lineCount,
    required this.quantityDelta,
    this.note,
  });

  /// Stable document or movement identifier.
  final String id;

  /// Business movement type.
  final InventoryMovementDocumentType type;

  /// User-facing title.
  final String title;

  /// Creation date.
  final DateTime createdAt;

  /// Number of detail rows.
  final int lineCount;

  /// Net quantity delta.
  final int quantityDelta;

  /// Optional note.
  final String? note;

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    createdAt,
    lineCount,
    quantityDelta,
    note,
  ];
}

/// One detail row for an inventory movement document.
final class InventoryMovementDocumentLine extends Equatable {
  /// Creates one movement detail line.
  const InventoryMovementDocumentLine({
    required this.productName,
    required this.quantityDelta,
    this.countedQuantity,
    this.stockBefore,
    this.unitCostInCents,
  });

  /// Product affected by the movement.
  final String productName;

  /// Positive or negative stock variation.
  final int quantityDelta;

  /// Stock before the adjustment, when available.
  final int? stockBefore;

  /// Counted stock for adjustments, when available.
  final int? countedQuantity;

  /// Unit cost in minor currency units, when available.
  final int? unitCostInCents;

  @override
  List<Object?> get props => [
    productName,
    quantityDelta,
    stockBefore,
    countedQuantity,
    unitCostInCents,
  ];
}
