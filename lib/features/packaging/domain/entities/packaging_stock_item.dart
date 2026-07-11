import 'package:equatable/equatable.dart';

/// Current stock for one packaging item.
final class PackagingStockItem extends Equatable {
  /// Creates a packaging stock row.
  const PackagingStockItem({
    required this.packagingItemId,
    required this.packagingName,
    required this.quantityOnHand,
    required this.updatedAt,
    this.costInCents = 0,
  });

  /// Packaging identifier.
  final String packagingItemId;

  /// Packaging visible name.
  final String packagingName;

  /// Current stock quantity.
  final int quantityOnHand;

  /// Current unit cost in minor currency units.
  final int costInCents;

  /// Last update.
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    packagingItemId,
    packagingName,
    quantityOnHand,
    costInCents,
    updatedAt,
  ];
}
