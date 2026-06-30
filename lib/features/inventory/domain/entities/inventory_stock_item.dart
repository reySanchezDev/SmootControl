import 'package:equatable/equatable.dart';

/// Current stock for one product.
final class InventoryStockItem extends Equatable {
  /// Creates a stock row.
  const InventoryStockItem({
    required this.productId,
    required this.productName,
    required this.quantityOnHand,
    required this.updatedAt,
  });

  /// Product identifier.
  final String productId;

  /// Product name.
  final String productName;

  /// Current stock.
  final int quantityOnHand;

  /// Last stock update.
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    productId,
    productName,
    quantityOnHand,
    updatedAt,
  ];
}
