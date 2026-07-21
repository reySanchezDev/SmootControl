import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

/// Product that can be sold from the POS.
final class Product extends Equatable {
  /// Creates a product.
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.priceInCents,
    required this.costInCents,
    required this.isActive,
    this.isAvailableInPos = true,
    this.isRawMaterial = false,
    this.usesRecipe = false,
    this.tracksInventory = false,
    this.purchaseUnitId,
    this.inventoryUnitId,
    this.recipeDefaultUnitId,
    this.inventoryDisplayUnitId,
    this.purchaseToInventoryFactor,
    this.optionGroups = const [],
    this.modifierGroupIds = const [],
  });

  /// Unique product identifier.
  final String id;

  /// Category or subcategory where the product is shown.
  final String categoryId;

  /// Visible product name.
  final String name;

  /// Sale price stored in minor currency units.
  final int priceInCents;

  /// Estimated product cost stored in minor currency units.
  final int costInCents;

  /// Whether the product can be sold.
  final bool isActive;

  /// Whether the product is visible for today's POS operation.
  final bool isAvailableInPos;

  /// Whether this item is inventory raw material, not sold directly.
  final bool isRawMaterial;

  /// Whether the product should explode recipe components remotely.
  final bool usesRecipe;

  /// Whether completed sales should consume inventory stock.
  final bool tracksInventory;

  /// Unit used when buying this product or raw material.
  final String? purchaseUnitId;

  /// Base unit used to store inventory stock.
  final String? inventoryUnitId;

  /// Suggested unit when this product is used as a recipe component.
  final String? recipeDefaultUnitId;

  /// Preferred unit for displaying and counting inventory.
  final String? inventoryDisplayUnitId;

  /// Quantity of base units produced by one purchase unit.
  final double? purchaseToInventoryFactor;

  /// Selection groups requested by the POS before adding this product.
  final List<ProductOptionGroup> optionGroups;

  /// Reusable modifier group identifiers assigned to this product.
  final List<String> modifierGroupIds;

  /// Whether the POS must request options before adding the product.
  bool get requiresOptionSelection =>
      optionGroups.isNotEmpty || modifierGroupIds.isNotEmpty;

  /// Estimated gross profit per unit.
  int get grossProfitInCents => priceInCents - costInCents;

  @override
  List<Object?> get props => [
    id,
    categoryId,
    name,
    priceInCents,
    costInCents,
    isActive,
    isAvailableInPos,
    isRawMaterial,
    usesRecipe,
    tracksInventory,
    purchaseUnitId,
    inventoryUnitId,
    recipeDefaultUnitId,
    inventoryDisplayUnitId,
    purchaseToInventoryFactor,
    optionGroups,
    modifierGroupIds,
  ];
}
