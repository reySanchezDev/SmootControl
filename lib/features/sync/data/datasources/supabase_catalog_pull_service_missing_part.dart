part of 'supabase_catalog_pull_service.dart';

extension on SupabaseCatalogPullService {
  Future<void> _markMissingCategoriesInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localProductCategories,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localProductCategories,
      )..where((category) => category.id.equals(row.id))).write(
        LocalProductCategoriesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingProductsInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database.select(_database.localProducts).get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) ||
          (!row.isActive && !row.isAvailableInPos)) {
        continue;
      }
      final hasOpenTicket = await _hasOpenTicketForProduct(row.id);
      await (_database.update(
        _database.localProducts,
      )..where((product) => product.id.equals(row.id))).write(
        LocalProductsCompanion(
          isActive: Value(hasOpenTicket),
          isAvailableInPos: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingModifierGroupsInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localModifierGroups,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localModifierGroups,
      )..where((group) => group.id.equals(row.id))).write(
        LocalModifierGroupsCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingModifierOptionsInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localModifierOptions,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) ||
          (!row.isActive && !row.isAvailableInPos)) {
        continue;
      }
      await (_database.update(
        _database.localModifierOptions,
      )..where((option) => option.id.equals(row.id))).write(
        LocalModifierOptionsCompanion(
          isActive: const Value(false),
          isAvailableInPos: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingSalesTypesInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database.select(_database.localSalesTypes).get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localSalesTypes,
      )..where((type) => type.id.equals(row.id))).write(
        LocalSalesTypesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingPackagingItemsInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(_database.localPackagingItems)
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localPackagingItems,
      )..where((item) => item.id.equals(row.id))).write(
        LocalPackagingItemsCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingPackagingRulesInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(_database.localProductPackagingRules)
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localProductPackagingRules,
      )..where((rule) => rule.id.equals(row.id))).write(
        LocalProductPackagingRulesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingPaymentMethodsInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localPaymentMethods,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localPaymentMethods,
      )..where((method) => method.id.equals(row.id))).write(
        LocalPaymentMethodsCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingTablesInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    if (remoteIds.isEmpty) return;
    final localRows = await _database
        .select(
          _database.localRestaurantTables,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      if (await _hasOpenTicketForTable(row.id)) continue;
      await (_database.update(
        _database.localRestaurantTables,
      )..where((table) => table.id.equals(row.id))).write(
        LocalRestaurantTablesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<void> _markMissingExpenseCategoriesInactive(
    Set<String> remoteIds,
    DateTime now,
  ) async {
    final localRows = await _database
        .select(
          _database.localExpenseCategories,
        )
        .get();
    for (final row in localRows) {
      if (remoteIds.contains(row.id) || !row.isActive) continue;
      await (_database.update(
        _database.localExpenseCategories,
      )..where((category) => category.id.equals(row.id))).write(
        LocalExpenseCategoriesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
          syncedAt: Value(now),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<bool> _hasOpenTicketForProduct(String productId) async {
    final row = await (_database.select(
      _database.localPosOpenTicketLines,
    )..where((line) => line.productId.equals(productId))).getSingleOrNull();
    return row != null;
  }

  Future<bool> _hasOpenTicketForTable(String tableId) async {
    final row = await (_database.select(
      _database.localPosOpenTicketLines,
    )..where((line) => line.tableId.equals(tableId))).getSingleOrNull();
    return row != null;
  }
}
