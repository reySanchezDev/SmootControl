import 'package:smoo_control/core/database/app_database.dart';

/// Contract for local-only POS product ordering preferences.
abstract interface class IPosProductOrderDataSource {
  /// Returns product display order by product id.
  Future<Map<String, int>> getProductOrderById();

  /// Saves the local order for the products in one category.
  Future<Map<String, int>> saveCategoryOrder({
    required String categoryId,
    required List<String> productIds,
  });

  /// Removes local product ordering for one category.
  Future<Map<String, int>> resetCategoryOrder(String categoryId);

  /// Returns table display order by table id.
  Future<Map<String, int>> getTableOrderById();

  /// Saves the local order for POS tables.
  Future<Map<String, int>> saveTableOrder({
    required List<String> tableIds,
  });
}

/// Stores POS product ordering preferences only in the local device database.
final class LocalPosProductOrderDataSource
    implements IPosProductOrderDataSource {
  /// Creates the datasource.
  const LocalPosProductOrderDataSource(this._database);

  final AppDatabase _database;

  /// Returns product display order by product id.
  @override
  Future<Map<String, int>> getProductOrderById() async {
    final rows = await _database
        .select(_database.localPosProductOrderPreferences)
        .get();
    return {
      for (final row in rows) row.productId: row.displayOrder,
    };
  }

  /// Saves the local order for the products in one category.
  @override
  Future<Map<String, int>> saveCategoryOrder({
    required String categoryId,
    required List<String> productIds,
  }) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      await (_database.delete(
        _database.localPosProductOrderPreferences,
      )..where((row) => row.categoryId.equals(categoryId))).go();

      await _database.batch((batch) {
        for (var index = 0; index < productIds.length; index += 1) {
          batch.insert(
            _database.localPosProductOrderPreferences,
            LocalPosProductOrderPreferencesCompanion.insert(
              categoryId: categoryId,
              productId: productIds[index],
              displayOrder: index,
              updatedAt: now,
            ),
          );
        }
      });
    });

    return getProductOrderById();
  }

  /// Removes local product ordering for one category.
  @override
  Future<Map<String, int>> resetCategoryOrder(String categoryId) async {
    await (_database.delete(
      _database.localPosProductOrderPreferences,
    )..where((row) => row.categoryId.equals(categoryId))).go();
    return getProductOrderById();
  }

  /// Returns table display order by table id.
  @override
  Future<Map<String, int>> getTableOrderById() async {
    final rows = await _database
        .select(_database.localPosTableOrderPreferences)
        .get();
    return {
      for (final row in rows) row.tableId: row.displayOrder,
    };
  }

  /// Saves the local order for POS tables.
  @override
  Future<Map<String, int>> saveTableOrder({
    required List<String> tableIds,
  }) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      await _database.delete(_database.localPosTableOrderPreferences).go();

      await _database.batch((batch) {
        for (var index = 0; index < tableIds.length; index += 1) {
          batch.insert(
            _database.localPosTableOrderPreferences,
            LocalPosTableOrderPreferencesCompanion.insert(
              tableId: tableIds[index],
              displayOrder: index,
              updatedAt: now,
            ),
          );
        }
      });
    });

    return getTableOrderById();
  }
}
