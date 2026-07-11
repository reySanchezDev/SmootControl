part of 'supabase_catalog_pull_service.dart';

extension on SupabaseCatalogPullService {
  Future<void> _applyInventoryStock(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final pendingDeltas = await _pendingInventoryDeltasByProduct();
    for (final row in rows) {
      final productId = _optionalText(row['product_id']);
      if (productId == null) continue;
      final remoteQuantity = _int(row['quantity_on_hand']);
      final localPendingDelta = pendingDeltas[productId] ?? 0;
      final adjustedQuantity = remoteQuantity + localPendingDelta;
      if (adjustedQuantity < 0) {
        throw StateError(
          'La descarga de inventario produciria stock negativo para '
          '$productId por movimientos locales pendientes.',
        );
      }
      await _database
          .into(_database.localInventoryStock)
          .insert(
            LocalInventoryStockCompanion(
              productId: Value(productId),
              quantityOnHand: Value(adjustedQuantity),
              remoteId: Value(productId),
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

  Future<void> _applySalesTypes(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'sales_types');
      remoteIds.add(id);
      await _database
          .into(_database.localSalesTypes)
          .insert(
            LocalSalesTypesCompanion(
              id: Value(id),
              code: Value(_text(row['code'], defaultValue: id)),
              name: Value(_text(row['name'], defaultValue: 'Tipo de venta')),
              displayOrder: Value(_int(row['display_order'])),
              isDefault: Value(_bool(row['is_default'])),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await _markMissingSalesTypesInactive(remoteIds, now);
  }

  Future<void> _applyPackagingItems(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'packaging_items');
      remoteIds.add(id);
      await _database
          .into(_database.localPackagingItems)
          .insert(
            LocalPackagingItemsCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Empaque')),
              costInCents: Value(_moneyCents(row['cost'])),
              tracksStock: Value(
                _bool(row['tracks_stock'], defaultValue: true),
              ),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await _markMissingPackagingItemsInactive(remoteIds, now);
  }

  Future<void> _applyProductPackagingRules(
    List<Map<String, Object?>> rows,
  ) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'product_packaging_rules');
      final productId = _optionalText(row['product_id']);
      final salesTypeId = _optionalText(row['sales_type_id']);
      final packagingItemId = _optionalText(row['packaging_item_id']);
      if (productId == null || salesTypeId == null || packagingItemId == null) {
        continue;
      }
      remoteIds.add(id);
      await _database
          .into(_database.localProductPackagingRules)
          .insert(
            LocalProductPackagingRulesCompanion(
              id: Value(id),
              productId: Value(productId),
              salesTypeId: Value(salesTypeId),
              packagingItemId: Value(packagingItemId),
              quantityPerUnit: Value(
                _int(row['quantity_per_unit'], defaultValue: 1),
              ),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await _markMissingPackagingRulesInactive(remoteIds, now);
  }

  Future<void> _applyPackagingStock(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final pendingDeltas = await _pendingPackagingDeltasByItem();
    for (final row in rows) {
      final packagingItemId = _optionalText(row['packaging_item_id']);
      if (packagingItemId == null) continue;
      final remoteQuantity = _int(row['quantity_on_hand']);
      final adjustedQuantity =
          remoteQuantity + (pendingDeltas[packagingItemId] ?? 0);
      if (adjustedQuantity < 0) {
        throw StateError(
          'La descarga de empaques produciria stock negativo para '
          '$packagingItemId por movimientos locales pendientes.',
        );
      }
      await _database
          .into(_database.localPackagingStock)
          .insert(
            LocalPackagingStockCompanion(
              packagingItemId: Value(packagingItemId),
              quantityOnHand: Value(adjustedQuantity),
              remoteId: Value(packagingItemId),
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

  Future<Map<String, int>> _pendingInventoryDeltasByProduct() async {
    final movements = await _database
        .select(_database.localInventoryMovements)
        .get();
    if (movements.isEmpty) return const {};

    final salesQueue = await (_database.select(
      _database.localSyncQueue,
    )..where((item) => item.entityType.equals('sales'))).get();
    final inventoryQueue = await (_database.select(
      _database.localSyncQueue,
    )..where((item) => item.entityType.equals('inventory_movements'))).get();
    final salesByEntity = _latestQueueByEntityId(salesQueue);
    final inventoryByEntity = _latestQueueByEntityId(inventoryQueue);

    final deltas = <String, int>{};
    for (final movement in movements) {
      if (!_shouldPreserveMovementDelta(
        movement,
        salesByEntity: salesByEntity,
        inventoryByEntity: inventoryByEntity,
      )) {
        continue;
      }
      deltas.update(
        movement.productId,
        (value) => value + movement.quantityDelta,
        ifAbsent: () => movement.quantityDelta,
      );
    }
    return deltas;
  }

  Future<Map<String, int>> _pendingPackagingDeltasByItem() async {
    final movements = await _database
        .select(_database.localPackagingMovements)
        .get();
    if (movements.isEmpty) return const {};

    final salesQueue = await (_database.select(
      _database.localSyncQueue,
    )..where((item) => item.entityType.equals('sales'))).get();
    final packagingQueue = await (_database.select(
      _database.localSyncQueue,
    )..where((item) => item.entityType.equals('packaging_movements'))).get();
    final salesByEntity = _latestQueueByEntityId(salesQueue);
    final packagingByEntity = _latestQueueByEntityId(packagingQueue);

    final deltas = <String, int>{};
    for (final movement in movements) {
      if (!_shouldPreservePackagingMovementDelta(
        movement,
        salesByEntity: salesByEntity,
        packagingByEntity: packagingByEntity,
      )) {
        continue;
      }
      deltas.update(
        movement.packagingItemId,
        (value) => value + movement.quantityDelta,
        ifAbsent: () => movement.quantityDelta,
      );
    }
    return deltas;
  }

  Map<String, LocalSyncQueueData> _latestQueueByEntityId(
    List<LocalSyncQueueData> rows,
  ) {
    final byEntityId = <String, LocalSyncQueueData>{};
    for (final row in rows) {
      final current = byEntityId[row.entityId];
      if (current == null || row.updatedAt.isAfter(current.updatedAt)) {
        byEntityId[row.entityId] = row;
      }
    }
    return byEntityId;
  }

  bool _shouldPreserveMovementDelta(
    LocalInventoryMovement movement, {
    required Map<String, LocalSyncQueueData> salesByEntity,
    required Map<String, LocalSyncQueueData> inventoryByEntity,
  }) {
    final referenceType = movement.referenceType;
    if (referenceType == 'sale' || referenceType == 'sale_void') {
      final referenceId = movement.referenceId;
      if (referenceId == null) return true;
      return _isNotSynced(salesByEntity[referenceId], missingIsPending: true);
    }

    if (referenceType == 'purchase') {
      return _isNotSynced(
        inventoryByEntity[movement.id],
        missingIsPending: false,
      );
    }

    return false;
  }

  bool _shouldPreservePackagingMovementDelta(
    LocalPackagingMovement movement, {
    required Map<String, LocalSyncQueueData> salesByEntity,
    required Map<String, LocalSyncQueueData> packagingByEntity,
  }) {
    final referenceType = movement.referenceType;
    if (referenceType == 'sale' || referenceType == 'sale_void') {
      final referenceId = movement.referenceId;
      if (referenceId == null) return true;
      return _isNotSynced(salesByEntity[referenceId], missingIsPending: true);
    }

    if (referenceType == 'packaging_purchase') {
      return _isNotSynced(
        packagingByEntity[movement.id],
        missingIsPending: false,
      );
    }

    return false;
  }

  bool _isNotSynced(
    LocalSyncQueueData? row, {
    required bool missingIsPending,
  }) {
    if (row == null) return missingIsPending;
    return row.status != 'synced';
  }
}
