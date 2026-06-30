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
    this.tracksInventory = false,
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

  /// Whether completed sales should consume inventory stock.
  final bool tracksInventory;

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
    tracksInventory,
    optionGroups,
    modifierGroupIds,
  ];
}
