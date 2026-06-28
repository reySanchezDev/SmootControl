import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/products/data/models/product_option_group_codec.dart';
import 'package:smoo_control/features/products/data/models/string_list_codec.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

/// Data model for products persisted locally or remotely.
final class ProductModel extends Equatable {
  /// Creates a product model.
  const ProductModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.priceInCents,
    required this.costInCents,
    required this.isActive,
    required this.isAvailableInPos,
    required this.optionGroups,
    required this.modifierGroupIds,
  });

  /// Creates a model from a local Drift row.
  factory ProductModel.fromLocal(LocalProduct row) {
    return ProductModel(
      id: row.id,
      categoryId: row.categoryId,
      name: row.name,
      priceInCents: row.priceInCents,
      costInCents: row.costInCents,
      isActive: row.isActive,
      isAvailableInPos: row.isAvailableInPos,
      optionGroups: ProductOptionGroupCodec.decode(row.optionGroupsJson),
      modifierGroupIds: StringListCodec.decode(row.modifierGroupIdsJson),
    );
  }

  /// Creates a model from a domain entity.
  factory ProductModel.fromEntity(Product entity) {
    return ProductModel(
      id: entity.id,
      categoryId: entity.categoryId,
      name: entity.name,
      priceInCents: entity.priceInCents,
      costInCents: entity.costInCents,
      isActive: entity.isActive,
      isAvailableInPos: entity.isAvailableInPos,
      optionGroups: entity.optionGroups,
      modifierGroupIds: entity.modifierGroupIds,
    );
  }

  /// Unique product identifier.
  final String id;

  /// Category or subcategory identifier.
  final String categoryId;

  /// Visible product name.
  final String name;

  /// Price in minor currency units.
  final int priceInCents;

  /// Cost in minor currency units.
  final int costInCents;

  /// Whether the product can be sold.
  final bool isActive;

  /// Whether the product is visible in the POS today.
  final bool isAvailableInPos;

  /// POS option groups configured for this product.
  final List<ProductOptionGroup> optionGroups;

  /// Reusable modifier group ids assigned to this product.
  final List<String> modifierGroupIds;

  /// Encoded POS option groups.
  String get optionGroupsJson => ProductOptionGroupCodec.encode(optionGroups);

  /// Encoded reusable modifier groups.
  String get modifierGroupIdsJson => StringListCodec.encode(modifierGroupIds);

  /// Converts this model to a domain entity.
  Product toEntity() {
    return Product(
      id: id,
      categoryId: categoryId,
      name: name,
      priceInCents: priceInCents,
      costInCents: costInCents,
      isActive: isActive,
      isAvailableInPos: isAvailableInPos,
      optionGroups: optionGroups,
      modifierGroupIds: modifierGroupIds,
    );
  }

  @override
  List<Object?> get props => [
    id,
    categoryId,
    name,
    priceInCents,
    costInCents,
    isActive,
    isAvailableInPos,
    optionGroups,
    modifierGroupIds,
  ];
}
