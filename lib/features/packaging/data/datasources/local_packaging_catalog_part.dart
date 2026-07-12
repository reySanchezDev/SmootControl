part of 'local_packaging_datasource.dart';

mixin _LocalPackagingCatalogMixin on _LocalPackagingDataSourceBase {
  Future<List<SalesType>> getSalesTypes() async {
    final rows =
        await (_database.select(_database.localSalesTypes)..orderBy([
              (type) => OrderingTerm.asc(type.displayOrder),
              (type) => OrderingTerm.asc(type.name),
            ]))
            .get();
    return rows.map(_salesTypeFromRow).toList();
  }

  /// Saves one sales type.
  Future<SalesType> saveSalesType(SalesType salesType) async {
    final now = DateTime.now();
    await _database.transaction(() async {
      if (salesType.isDefault) {
        await _database
            .update(_database.localSalesTypes)
            .write(
              LocalSalesTypesCompanion(
                isDefault: const Value(false),
                updatedAt: Value(now),
              ),
            );
      }
      await _database
          .into(_database.localSalesTypes)
          .insertOnConflictUpdate(
            LocalSalesTypesCompanion(
              id: Value(salesType.id),
              code: Value(salesType.code),
              name: Value(salesType.name),
              displayOrder: Value(salesType.displayOrder),
              isDefault: Value(salesType.isDefault),
              isActive: Value(salesType.isActive),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });
    return salesType;
  }

  /// Returns packaging items.
  Future<List<PackagingItem>> getPackagingItems() async {
    final rows = await (_database.select(
      _database.localPackagingItems,
    )..orderBy([(item) => OrderingTerm.asc(item.name)])).get();
    return rows.map(_packagingItemFromRow).toList();
  }

  /// Saves one packaging item.
  Future<PackagingItem> savePackagingItem(PackagingItem item) async {
    final now = DateTime.now();
    await _database
        .into(_database.localPackagingItems)
        .insertOnConflictUpdate(
          LocalPackagingItemsCompanion(
            id: Value(item.id),
            name: Value(item.name),
            costInCents: Value(item.costInCents),
            tracksStock: Value(item.tracksStock),
            isActive: Value(item.isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return item;
  }

  /// Returns packaging rules.
  Future<List<ProductPackagingRule>> getRules() async {
    final rows =
        await (_database.select(_database.localProductPackagingRules)..orderBy([
              (rule) => OrderingTerm.asc(rule.productId),
              (rule) => OrderingTerm.asc(rule.salesTypeId),
            ]))
            .get();
    return rows.map(_ruleFromRow).toList();
  }

  /// Saves one packaging rule.
  Future<ProductPackagingRule> saveRule(ProductPackagingRule rule) async {
    final now = DateTime.now();
    await _database
        .into(_database.localProductPackagingRules)
        .insertOnConflictUpdate(
          LocalProductPackagingRulesCompanion(
            id: Value(rule.id),
            productId: Value(rule.productId),
            salesTypeId: Value(rule.salesTypeId),
            packagingItemId: Value(rule.packagingItemId),
            quantityPerUnit: Value(rule.quantityPerUnit),
            isActive: Value(rule.isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return rule;
  }
}
