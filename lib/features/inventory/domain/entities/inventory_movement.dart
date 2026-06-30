import 'package:equatable/equatable.dart';

/// Inventory movement type.
enum InventoryMovementType {
  /// Purchase increases stock.
  purchase,

  /// Sale decreases stock.
  sale,

  /// Sale void restores stock.
  saleVoid,
}

/// Auditable inventory movement.
final class InventoryMovement extends Equatable {
  /// Creates a movement.
  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantityDelta,
    required this.createdAt,
    this.referenceType,
    this.referenceId,
    this.userId,
    this.notes,
  });

  /// Stable movement id.
  final String id;

  /// Product affected.
  final String productId;

  /// Movement type.
  final InventoryMovementType movementType;

  /// Signed quantity delta.
  final int quantityDelta;

  /// Origin type.
  final String? referenceType;

  /// Origin id.
  final String? referenceId;

  /// User id.
  final String? userId;

  /// Optional notes.
  final String? notes;

  /// Creation time.
  final DateTime createdAt;

  /// Value persisted in local/remotes tables.
  String get typeValue => switch (movementType) {
    InventoryMovementType.purchase => 'purchase',
    InventoryMovementType.sale => 'sale',
    InventoryMovementType.saleVoid => 'sale_void',
  };

  @override
  List<Object?> get props => [
    id,
    productId,
    movementType,
    quantityDelta,
    referenceType,
    referenceId,
    userId,
    notes,
    createdAt,
  ];
}
