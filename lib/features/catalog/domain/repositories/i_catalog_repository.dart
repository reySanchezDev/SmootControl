import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';

/// Contract for product category persistence.
abstract interface class ICatalogRepository {
  /// Returns all configured categories and subcategories.
  Future<AppResult<List<ProductCategory>>> getCategories();

  /// Saves a category or subcategory.
  Future<AppResult<ProductCategory>> saveCategory(ProductCategory category);

  /// Removes a subcategory level and moves its direct content to its parent.
  Future<AppResult<ProductCategory>> removeCategoryLevel(
    ProductCategory category,
  );
}
