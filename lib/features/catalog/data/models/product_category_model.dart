import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';

/// Data model for product categories persisted locally or remotely.
final class ProductCategoryModel extends Equatable {
  /// Creates a product category model.
  const ProductCategoryModel({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    this.parentId,
  });

  /// Creates a model from a local Drift row.
  factory ProductCategoryModel.fromLocal(LocalProductCategory row) {
    return ProductCategoryModel(
      id: row.id,
      name: row.name,
      parentId: row.parentId,
      sortOrder: row.sortOrder,
      isActive: row.isActive,
    );
  }

  /// Creates a model from a domain entity.
  factory ProductCategoryModel.fromEntity(ProductCategory entity) {
    return ProductCategoryModel(
      id: entity.id,
      name: entity.name,
      parentId: entity.parentId,
      sortOrder: entity.sortOrder,
      isActive: entity.isActive,
    );
  }

  /// Unique category identifier.
  final String id;

  /// Visible category name.
  final String name;

  /// Parent category identifier when this is a subcategory.
  final String? parentId;

  /// Sorting position in POS grids.
  final int sortOrder;

  /// Whether the category can be used.
  final bool isActive;

  /// Converts this model to a domain entity.
  ProductCategory toEntity() {
    return ProductCategory(
      id: id,
      name: name,
      parentId: parentId,
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }

  @override
  List<Object?> get props => [id, name, parentId, sortOrder, isActive];
}
