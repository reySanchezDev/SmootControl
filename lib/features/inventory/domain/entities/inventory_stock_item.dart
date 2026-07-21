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
    this.inventoryDisplayUnitId,
    this.inventoryDisplayUnitName,
    this.purchaseToInventoryFactor,
    this.purchaseUnitId,
    this.purchaseUnitName,
  });

  /// Product identifier.
  final String productId;

  /// Product name.
  final String productName;

  /// Current stock in the inventory base unit.
  final double quantityOnHand;

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

  /// Preferred inventory display/count unit id.
  final String? inventoryDisplayUnitId;

  /// Preferred inventory display/count unit display name.
  final String? inventoryDisplayUnitName;

  /// Conversion from one purchase unit to inventory units.
  final double? purchaseToInventoryFactor;

  /// Quantity converted to the preferred display/count unit.
  double get displayQuantity {
    if (inventoryDisplayUnitId == null ||
        inventoryDisplayUnitId == inventoryUnitId) {
      return quantityOnHand;
    }
    if (inventoryDisplayUnitId == purchaseUnitId &&
        purchaseToInventoryFactor != null &&
        purchaseToInventoryFactor! > 0) {
      return quantityOnHand / purchaseToInventoryFactor!;
    }
    return quantityOnHand;
  }

  /// Preferred display/count unit name.
  String? get displayUnitName {
    if (inventoryDisplayUnitName != null) return inventoryDisplayUnitName;
    if (inventoryDisplayUnitId == purchaseUnitId) return purchaseUnitName;
    if (inventoryDisplayUnitId == inventoryUnitId) return inventoryUnitName;
    return inventoryUnitName;
  }

  /// Converts user-entered display/count units to inventory base units.
  double displayToBase(double value) {
    if (inventoryDisplayUnitId == purchaseUnitId &&
        purchaseToInventoryFactor != null &&
        purchaseToInventoryFactor! > 0) {
      return value * purchaseToInventoryFactor!;
    }
    return value;
  }

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
    inventoryDisplayUnitId,
    inventoryDisplayUnitName,
    purchaseToInventoryFactor,
    updatedAt,
  ];
}
