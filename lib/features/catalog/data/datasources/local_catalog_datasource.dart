import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/catalog/data/models/product_category_model.dart';

/// Local datasource for product categories.
final class LocalCatalogDataSource {
  /// Creates a local catalog datasource.
  const LocalCatalogDataSource(this._database);

  final AppDatabase _database;

  /// Returns categories stored locally.
  Future<List<ProductCategoryModel>> getCategories() async {
    final query = _database.select(_database.localProductCategories)
      ..orderBy([
        (category) => OrderingTerm.asc(category.sortOrder),
        (category) => OrderingTerm.asc(category.name),
      ]);
    final rows = await query.get();

    return rows.map(ProductCategoryModel.fromLocal).toList();
  }

  /// Inserts or updates a local category.
  Future<ProductCategoryModel> saveCategory(
    ProductCategoryModel category,
  ) async {
    final now = DateTime.now();

    await _database
        .into(_database.localProductCategories)
        .insertOnConflictUpdate(
          LocalProductCategoriesCompanion(
            id: Value(category.id),
            name: Value(category.name),
            parentId: Value(category.parentId),
            sortOrder: Value(category.sortOrder),
            isActive: Value(category.isActive),
            updatedAt: Value(now),
            createdAt: Value(now),
          ),
        );

    return category;
  }

  /// Deletes one category level and moves direct children/products to parent.
  Future<void> removeCategoryLevel({
    required String categoryId,
    required String parentId,
  }) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      await (_database.update(
        _database.localProductCategories,
      )..where((category) => category.parentId.equals(categoryId))).write(
        LocalProductCategoriesCompanion(
          parentId: Value(parentId),
          updatedAt: Value(now),
        ),
      );

      await (_database.update(
        _database.localProducts,
      )..where((product) => product.categoryId.equals(categoryId))).write(
        LocalProductsCompanion(
          categoryId: Value(parentId),
          updatedAt: Value(now),
        ),
      );

      await (_database.delete(
        _database.localProductCategories,
      )..where((category) => category.id.equals(categoryId))).go();
    });
  }
}
