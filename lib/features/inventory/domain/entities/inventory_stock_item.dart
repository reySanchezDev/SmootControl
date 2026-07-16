import 'package:equatable/equatable.dart';

/// Current stock for one product.
final class InventoryStockItem extends Equatable {
  /// Creates a stock row.
  const InventoryStockItem({
    required this.productId,
    required this.productName,
    required this.quantityOnHand,
    required this.updatedAt,
    this.categoryName,
    this.categoryPath,
    this.costInCents = 0,
    this.inventoryUnitId,
    this.inventoryUnitName,
    this.purchaseToInventoryFactor,
    this.purchaseUnitId,
    this.purchaseUnitName,
  });

  /// Product identifier.
  final String productId;

  /// Product name.
  final String productName;

  /// Current stock.
  final int quantityOnHand;

  /// Current unit cost in minor currency units.
  final int costInCents;

  /// Direct category or subcategory name.
  final String? categoryName;

  /// Full category path used by administrative filters.
  final String? categoryPath;

  /// Unit usually used when this product is purchased.
  final String? purchaseUnitId;

  /// Purchase unit display name.
  final String? purchaseUnitName;

  /// Base unit used to store inventory.
  final String? inventoryUnitId;

  /// Inventory unit display name.
  final String? inventoryUnitName;

  /// Conversion from one purchase unit to inventory units.
  final double? purchaseToInventoryFactor;

  /// Last stock update.
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    productId,
    productName,
    quantityOnHand,
    costInCents,
    categoryName,
    categoryPath,
    purchaseUnitId,
    purchaseUnitName,
    inventoryUnitId,
    inventoryUnitName,
    purchaseToInventoryFactor,
    updatedAt,
  ];
}
