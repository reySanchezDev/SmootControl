import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sync/domain/entities/item_catalog_snapshot_v2.dart';

/// Applies a validated canonical V2 snapshot without touching legacy POS data.
final class ItemCatalogSnapshotApplier {
  /// Creates an applier for the local Drift database.
  const ItemCatalogSnapshotApplier(this._database);

  final AppDatabase _database;

  /// Applies a newer snapshot in one transaction, or returns `false` on replay.
  ///
  /// Drift rolls back every canonical table change if any insert fails. The
  /// legacy catalog, sales and synchronization queue are never modified.
  Future<bool> apply(ItemCatalogSnapshotV2 snapshot) async {
    final stored =
        await (_database.select(
              _database.localCanonicalCatalogSnapshots,
            )..where((row) => row.restaurantId.equals(snapshot.restaurantId)))
            .getSingleOrNull();
    final decision = snapshot.decideAgainst(
      storedRevision: stored?.revision,
      storedSnapshotId: stored?.snapshotId,
    );
    if (decision == ItemCatalogUpdateDecisionV2.noChange) return false;

    final now = DateTime.now();
    await _database.transaction(() async {
      await _database.delete(_database.localCanonicalClassificationLinks).go();
      await _database.delete(_database.localCanonicalConsumptionRules).go();
      await _database.delete(_database.localCanonicalItemUnits).go();
      await _database.delete(_database.localCanonicalClassifications).go();
      await _database.delete(_database.localCanonicalItems).go();

      for (final item in snapshot.items) {
        await _database
            .into(_database.localCanonicalItems)
            .insert(
              LocalCanonicalItemsCompanion.insert(
                id: item.id,
                restaurantId: snapshot.restaurantId,
                code: item.code,
                name: item.name,
                itemType: _itemType(item.type),
                baseUnitId: item.baseUnitId,
                canSell: item.canSell,
                visibleInPos: item.visibleInPos,
                isActive: item.isActive,
              ),
            );
      }
      for (final unit in snapshot.units) {
        await _database
            .into(_database.localCanonicalItemUnits)
            .insert(
              LocalCanonicalItemUnitsCompanion.insert(
                itemId: unit.itemId,
                unitId: unit.unitId,
                quantityInBase: unit.quantityInBase,
              ),
            );
      }
      for (final classification in snapshot.classifications) {
        await _database
            .into(_database.localCanonicalClassifications)
            .insert(
              LocalCanonicalClassificationsCompanion.insert(
                id: classification.id,
                restaurantId: snapshot.restaurantId,
                code: classification.code,
                name: classification.name,
                isActive: classification.isActive,
              ),
            );
      }
      for (final link in snapshot.classificationLinks) {
        await _database
            .into(_database.localCanonicalClassificationLinks)
            .insert(
              LocalCanonicalClassificationLinksCompanion.insert(
                itemId: link.itemId,
                classificationId: link.classificationId,
              ),
            );
      }
      for (final rule in snapshot.consumptionRules) {
        await _database
            .into(_database.localCanonicalConsumptionRules)
            .insert(
              LocalCanonicalConsumptionRulesCompanion.insert(
                id: rule.id,
                restaurantId: snapshot.restaurantId,
                sourceItemId: Value(rule.sourceItemId),
                consumedItemId: rule.consumedItemId,
                unitId: rule.unitId,
                scope: rule.scope,
                quantity: rule.quantity,
              ),
            );
      }
      await _database
          .into(_database.localCanonicalCatalogSnapshots)
          .insertOnConflictUpdate(
            LocalCanonicalCatalogSnapshotsCompanion.insert(
              restaurantId: snapshot.restaurantId,
              snapshotId: snapshot.snapshotId,
              revision: snapshot.revision,
              appliedAt: now,
            ),
          );
    });
    return true;
  }

  String _itemType(ItemCatalogTypeV2 type) {
    return switch (type) {
      ItemCatalogTypeV2.inventory => 'inventory',
      ItemCatalogTypeV2.nonInventory => 'non_inventory',
      ItemCatalogTypeV2.service => 'service',
    };
  }
}
