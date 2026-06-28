import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/products/data/models/product_model.dart';

/// Local datasource for products.
final class LocalProductsDataSource {
  /// Creates a local products datasource.
  const LocalProductsDataSource(this._database);

  final AppDatabase _database;

  /// Returns products stored locally.
  Future<List<ProductModel>> getProducts() async {
    final query = _database.select(_database.localProducts)
      ..orderBy([
        (product) => OrderingTerm.asc(product.categoryId),
        (product) => OrderingTerm.asc(product.name),
      ]);
    final rows = await query.get();

    return rows.map(ProductModel.fromLocal).toList();
  }

  /// Inserts or updates a local product.
  Future<ProductModel> saveProduct(ProductModel product) async {
    final now = DateTime.now();

    await _database
        .into(_database.localProducts)
        .insertOnConflictUpdate(
          LocalProductsCompanion(
            id: Value(product.id),
            categoryId: Value(product.categoryId),
            name: Value(product.name),
            priceInCents: Value(product.priceInCents),
            costInCents: Value(product.costInCents),
            isActive: Value(product.isActive),
            isAvailableInPos: Value(product.isAvailableInPos),
            optionGroupsJson: Value(product.optionGroupsJson),
            modifierGroupIdsJson: Value(product.modifierGroupIdsJson),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return product;
  }
}
