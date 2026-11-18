import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';

/// Projects the validated canonical item snapshot into the POS read model.
///
/// This is a single transitional projection: POS reads one local product model
/// while the remote source of truth is migrated from products to items.
final class CanonicalItemPosProjector {
  /// Creates a projector for the local POS read model.
  const CanonicalItemPosProjector(this._database);

  final AppDatabase _database;

  static const _uncategorizedId = '__canonical_uncategorized__';

  /// Replaces only rows previously projected from the canonical item master.
  Future<void> project(String restaurantId) async {
    final items = await (_database.select(
      _database.localCanonicalItems,
    )..where((row) => row.restaurantId.equals(restaurantId))).get();
    final now = DateTime.now();
    final visibleIds = <String>{};

    await _database.transaction(() async {
      if (items.any((item) => item.categoryId == null)) {
        await _database
            .into(_database.localProductCategories)
            .insert(
              LocalProductCategoriesCompanion(
                id: const Value(_uncategorizedId),
                name: const Value('Sin categoría'),
                sortOrder: const Value(999999),
                isActive: const Value(true),
                remoteId: const Value(_uncategorizedId),
                syncStatus: const Value('synced'),
                syncError: const Value(null),
                createdAt: Value(now),
                updatedAt: Value(now),
                syncedAt: Value(now),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }

      for (final item in items) {
        if (!item.canSell || !item.visibleInPos || !item.isActive) continue;
        visibleIds.add(item.id);
        await _database
            .into(_database.localProducts)
            .insert(
              LocalProductsCompanion(
                id: Value(item.id),
                categoryId: Value(item.categoryId ?? _uncategorizedId),
                name: Value(item.name),
                priceInCents: Value(item.priceInCents),
                costInCents: Value(item.costInCents),
                isActive: const Value(true),
                isAvailableInPos: const Value(true),
                isRawMaterial: const Value(false),
                tracksInventory: Value(item.tracksInventory),
                optionGroupsJson: const Value('[]'),
                modifierGroupIdsJson: const Value('[]'),
                sourceKind: const Value('canonical_item'),
                remoteId: Value(item.id),
                syncStatus: const Value('synced'),
                syncError: const Value(null),
                createdAt: Value(now),
                updatedAt: Value(now),
                syncedAt: Value(now),
              ),
              mode: InsertMode.insertOrReplace,
            );
        if (item.tracksInventory) {
          await _database
              .into(_database.localInventoryStock)
              .insert(
                LocalInventoryStockCompanion(
                  productId: Value(item.id),
                  quantityOnHand: Value(item.quantityOnHand),
                  remoteId: Value(item.id),
                  syncStatus: const Value('synced'),
                  syncError: const Value(null),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                  syncedAt: Value(now),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      }

      final projected = await (_database.select(
        _database.localProducts,
      )..where((row) => row.sourceKind.equals('canonical_item'))).get();
      for (final product in projected) {
        if (visibleIds.contains(product.id)) continue;
        await (_database.update(
          _database.localProducts,
        )..where((row) => row.id.equals(product.id))).write(
          const LocalProductsCompanion(
            isActive: Value(false),
            isAvailableInPos: Value(false),
          ),
        );
      }
    });
  }
}
