part of 'local_packaging_datasource.dart';

mixin _LocalPackagingMovementsMixin on _LocalPackagingDataSourceBase {
  Future<List<PackagingStockItem>> getPackagingStock() async {
    final items =
        await (_database.select(_database.localPackagingItems)
              ..where((item) => item.isActive.equals(true))
              ..orderBy([(item) => OrderingTerm.asc(item.name)]))
            .get();
    final stock = <PackagingStockItem>[];
    for (final item in items) {
      final row = await _stockRow(item.id);
      stock.add(
        PackagingStockItem(
          packagingItemId: item.id,
          packagingName: item.name,
          quantityOnHand: row?.quantityOnHand ?? 0,
          updatedAt: row?.updatedAt ?? item.updatedAt,
        ),
      );
    }
    return stock;
  }

  /// Applies an already-created purchase movement locally.
  Future<void> applyPurchaseMovement(PackagingMovement movement) async {
    final now = DateTime.now();
    await _database.transaction(() async {
      await _applyMovement(movement, now: now);
    });
  }

  /// Creates packaging sale movements for one sale.
  Future<List<PackagingMovement>> applySaleMovements({
    required String saleId,
    required String? salesTypeId,
    required List<SaleItemModel> items,
    required String userId,
  }) async {
    if (salesTypeId == null || salesTypeId.isEmpty) return const [];
    if (!await _salesTypeConsumesPackaging(salesTypeId)) return const [];
    final now = DateTime.now();
    final requiredByPackaging = await _requiredPackagingByItem(
      salesTypeId: salesTypeId,
      items: items,
    );
    final movements = <PackagingMovement>[];
    for (final entry in requiredByPackaging.entries) {
      final item = await _packagingItem(entry.key);
      if (item == null || !item.isActive) continue;
      if (item.tracksStock) {
        final stock = await _stockRow(item.id);
        final available = stock?.quantityOnHand ?? 0;
        if (available < entry.value) {
          throw PackagingStockException(
            packagingName: item.name,
            available: available,
            requested: entry.value,
          );
        }
      }
      final movement = PackagingMovement(
        id: 'packaging-sale-$saleId-${item.id}',
        packagingItemId: item.id,
        movementType: PackagingMovementType.sale,
        quantityDelta: -entry.value,
        unitCostInCents: item.costInCents,
        referenceType: 'sale',
        referenceId: saleId,
        userId: userId,
        createdAt: now,
      );
      await _applyMovement(movement, now: now);
      movements.add(movement);
    }
    return movements;
  }

  /// Creates inverse packaging movements for a sale void.
  Future<List<PackagingMovement>> applySaleVoidMovements({
    required String saleId,
    required String userId,
  }) async {
    final originalMovements =
        await (_database.select(_database.localPackagingMovements)..where(
              (movement) =>
                  movement.referenceType.equals('sale') &
                  movement.referenceId.equals(saleId) &
                  movement.movementType.equals('packaging_sale'),
            ))
            .get();
    final now = DateTime.now();
    final movements = <PackagingMovement>[];
    for (final original in originalMovements) {
      final movement = PackagingMovement(
        id: 'packaging-sale-void-$saleId-${original.packagingItemId}',
        packagingItemId: original.packagingItemId,
        movementType: PackagingMovementType.saleVoid,
        quantityDelta: -original.quantityDelta,
        unitCostInCents: original.unitCostInCents,
        referenceType: 'sale_void',
        referenceId: saleId,
        userId: userId,
        createdAt: now,
      );
      await _applyMovement(movement, now: now);
      movements.add(movement);
    }
    return movements;
  }

  /// Returns packaging movements by reference.
  Future<List<PackagingMovement>> getMovementsForReference({
    required String referenceType,
    required String referenceId,
  }) async {
    final rows =
        await (_database.select(_database.localPackagingMovements)
              ..where(
                (movement) =>
                    movement.referenceType.equals(referenceType) &
                    movement.referenceId.equals(referenceId),
              )
              ..orderBy([(movement) => OrderingTerm.asc(movement.createdAt)]))
            .get();
    return rows.map(_movementFromRow).toList();
  }

  /// Creates a purchase movement for packaging.
  PackagingMovement purchaseMovement({
    required String packagingItemId,
    required int quantity,
    required int unitCostInCents,
    required String userId,
    String? notes,
  }) {
    return PackagingMovement(
      id: _uuid.v4(),
      packagingItemId: packagingItemId,
      movementType: PackagingMovementType.purchase,
      quantityDelta: quantity,
      unitCostInCents: unitCostInCents,
      referenceType: 'packaging_purchase',
      userId: userId,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }
}
