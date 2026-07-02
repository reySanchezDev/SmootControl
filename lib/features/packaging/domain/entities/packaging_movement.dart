import 'package:equatable/equatable.dart';

/// Packaging movement type.
enum PackagingMovementType {
  /// Purchase increases stock.
  purchase,

  /// Sale decreases stock.
  sale,

  /// Sale void restores stock.
  saleVoid,
}

/// Auditable packaging stock movement.
final class PackagingMovement extends Equatable {
  /// Creates a packaging movement.
  const PackagingMovement({
    required this.id,
    required this.packagingItemId,
    required this.movementType,
    required this.quantityDelta,
    required this.unitCostInCents,
    required this.createdAt,
    this.referenceType,
    this.referenceId,
    this.userId,
    this.notes,
  });

  /// Stable movement id.
  final String id;

  /// Packaging item affected.
  final String packagingItemId;

  /// Movement type.
  final PackagingMovementType movementType;

  /// Signed quantity delta.
  final int quantityDelta;

  /// Historical unit cost.
  final int unitCostInCents;

  /// Origin type.
  final String? referenceType;

  /// Origin id.
  final String? referenceId;

  /// User id.
  final String? userId;

  /// Optional note.
  final String? notes;

  /// Creation time.
  final DateTime createdAt;

  /// Value persisted in local/remote tables.
  String get typeValue => switch (movementType) {
    PackagingMovementType.purchase => 'packaging_purchase',
    PackagingMovementType.sale => 'packaging_sale',
    PackagingMovementType.saleVoid => 'packaging_sale_void',
  };

  @override
  List<Object?> get props => [
    id,
    packagingItemId,
    movementType,
    quantityDelta,
    unitCostInCents,
    referenceType,
    referenceId,
    userId,
    notes,
    createdAt,
  ];
}
