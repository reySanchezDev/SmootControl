import 'package:equatable/equatable.dart';

/// Current stock for one packaging item.
final class PackagingStockItem extends Equatable {
  /// Creates a packaging stock row.
  const PackagingStockItem({
    required this.packagingItemId,
    required this.packagingName,
    required this.quantityOnHand,
    required this.updatedAt,
  });

  /// Packaging identifier.
  final String packagingItemId;

  /// Packaging visible name.
  final String packagingName;

  /// Current stock quantity.
  final int quantityOnHand;

  /// Last update.
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    packagingItemId,
    packagingName,
    quantityOnHand,
    updatedAt,
  ];
}
