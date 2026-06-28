import 'package:equatable/equatable.dart';

/// Product category or subcategory shown in the POS.
final class ProductCategory extends Equatable {
  /// Creates a product category.
  const ProductCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    this.parentId,
  });

  /// Unique category identifier.
  final String id;

  /// Visible category name.
  final String name;

  /// Parent category identifier when this is a subcategory.
  final String? parentId;

  /// Sorting position in the POS.
  final int sortOrder;

  /// Whether the category can be used in sales.
  final bool isActive;

  /// Returns true when this category is a subcategory.
  bool get isSubcategory => parentId != null;

  /// Creates a modified copy.
  ProductCategory copyWith({
    String? id,
    String? name,
    String? parentId,
    int? sortOrder,
    bool? isActive,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, name, parentId, sortOrder, isActive];
}
