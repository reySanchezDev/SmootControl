part of 'local_packaging_datasource.dart';

abstract class _LocalPackagingDataSourceBase {
  const _LocalPackagingDataSourceBase(
    AppDatabase database, {
    Uuid uuid = const Uuid(),
  }) : _database = database,
       _uuid = uuid;

  final AppDatabase _database;
  final Uuid _uuid;
  Future<void> _applyMovement(
    PackagingMovement movement, {
    required DateTime now,
  }) async {
    final existing = await (_database.select(
      _database.localPackagingMovements,
    )..where((row) => row.id.equals(movement.id))).getSingleOrNull();
    if (existing != null) return;

    final item = await _packagingItem(movement.packagingItemId);
    if (item == null) {
      throw StateError('Empaque no existe: ${movement.packagingItemId}.');
    }
    final stock = await _stockRow(movement.packagingItemId);
    final nextQuantity = (stock?.quantityOnHand ?? 0) + movement.quantityDelta;
    if (item.tracksStock && nextQuantity < 0) {
      throw PackagingStockException(
        packagingName: item.name,
        available: stock?.quantityOnHand ?? 0,
        requested: -movement.quantityDelta,
      );
    }

    await _database
        .into(_database.localPackagingMovements)
        .insert(
          LocalPackagingMovementsCompanion.insert(
            id: movement.id,
            packagingItemId: movement.packagingItemId,
            movementType: movement.typeValue,
            quantityDelta: movement.quantityDelta,
            unitCostInCents: Value(movement.unitCostInCents),
            referenceType: Value(movement.referenceType),
            referenceId: Value(movement.referenceId),
            userId: Value(movement.userId),
            notes: Value(movement.notes),
            syncStatus: const Value('pending'),
            createdAt: movement.createdAt,
            updatedAt: now,
          ),
        );

    if (!item.tracksStock) return;

    await _database
        .into(_database.localPackagingStock)
        .insertOnConflictUpdate(
          LocalPackagingStockCompanion(
            packagingItemId: Value(movement.packagingItemId),
            quantityOnHand: Value(nextQuantity),
            syncStatus: const Value('pending'),
            createdAt: Value(stock?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<Map<String, int>> _requiredPackagingByItem({
    required String salesTypeId,
    required List<SaleItemModel> items,
  }) async {
    final productQuantities = <String, int>{};
    for (final item in items) {
      productQuantities.update(
        item.productId,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    final required = <String, int>{};
    for (final entry in productQuantities.entries) {
      final rules =
          await (_database.select(_database.localProductPackagingRules)..where(
                (rule) =>
                    rule.productId.equals(entry.key) &
                    rule.salesTypeId.equals(salesTypeId) &
                    rule.isActive.equals(true),
              ))
              .get();
      for (final rule in rules) {
        required.update(
          rule.packagingItemId,
          (quantity) => quantity + (entry.value * rule.quantityPerUnit),
          ifAbsent: () => entry.value * rule.quantityPerUnit,
        );
      }
    }
    return required;
  }

  Future<bool> _salesTypeConsumesPackaging(String salesTypeId) async {
    final salesType =
        await (_database.select(_database.localSalesTypes)..where(
              (row) => row.id.equals(salesTypeId) & row.isActive.equals(true),
            ))
            .getSingleOrNull();
    if (salesType == null) return false;

    return salesType.code.trim().toLowerCase() == 'to_go';
  }

  Future<LocalPackagingItem?> _packagingItem(String id) {
    return (_database.select(
      _database.localPackagingItems,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<LocalPackagingStockData?> _stockRow(String packagingItemId) {
    return (_database.select(_database.localPackagingStock)
          ..where((row) => row.packagingItemId.equals(packagingItemId)))
        .getSingleOrNull();
  }

  SalesType _salesTypeFromRow(LocalSalesType row) {
    return SalesType(
      id: row.id,
      code: row.code,
      name: row.name,
      displayOrder: row.displayOrder,
      isDefault: row.isDefault,
      isActive: row.isActive,
    );
  }

  PackagingItem _packagingItemFromRow(LocalPackagingItem row) {
    return PackagingItem(
      id: row.id,
      name: row.name,
      costInCents: row.costInCents,
      tracksStock: row.tracksStock,
      isActive: row.isActive,
    );
  }

  ProductPackagingRule _ruleFromRow(LocalProductPackagingRule row) {
    return ProductPackagingRule(
      id: row.id,
      productId: row.productId,
      salesTypeId: row.salesTypeId,
      packagingItemId: row.packagingItemId,
      quantityPerUnit: row.quantityPerUnit,
      isActive: row.isActive,
    );
  }

  PackagingMovement _movementFromRow(LocalPackagingMovement row) {
    return PackagingMovement(
      id: row.id,
      packagingItemId: row.packagingItemId,
      movementType: switch (row.movementType) {
        'packaging_sale' => PackagingMovementType.sale,
        'packaging_sale_void' => PackagingMovementType.saleVoid,
        _ => PackagingMovementType.purchase,
      },
      quantityDelta: row.quantityDelta,
      unitCostInCents: row.unitCostInCents,
      referenceType: row.referenceType,
      referenceId: row.referenceId,
      userId: row.userId,
      notes: row.notes,
      createdAt: row.createdAt,
    );
  }
}
