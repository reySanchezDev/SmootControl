import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/inventory/data/datasources/inventory_stock_exception.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_movement.dart';
import 'package:smoo_control/features/inventory/domain/entities/inventory_stock_item.dart';
import 'package:smoo_control/features/sales/data/models/sale_item_model.dart';
import 'package:uuid/uuid.dart';

/// Local datasource for stock and movements.
final class LocalInventoryDataSource {
  /// Creates the datasource.
  const LocalInventoryDataSource(this._database, {Uuid uuid = const Uuid()})
    : _uuid = uuid;

  final AppDatabase _database;
  final Uuid _uuid;

  /// Returns stock for products that control inventory.
  Future<List<InventoryStockItem>> getTrackedStock() async {
    final products =
        await (_database.select(_database.localProducts)
              ..where((product) => product.tracksInventory.equals(true))
              ..orderBy([(product) => OrderingTerm.asc(product.name)]))
            .get();
    final items = <InventoryStockItem>[];
    for (final product in products) {
      final stock = await _stockRow(product.id);
      items.add(
        InventoryStockItem(
          productId: product.id,
          productName: product.name,
          quantityOnHand: stock?.quantityOnHand ?? 0,
          updatedAt: stock?.updatedAt ?? product.updatedAt,
        ),
      );
    }
    return items;
  }

  /// Registers a purchase and increases stock.
  Future<InventoryMovement> registerPurchase({
    required String productId,
    required int quantity,
    required String userId,
    String? notes,
  }) async {
    final now = DateTime.now();
    final movement = InventoryMovement(
      id: _uuid.v4(),
      productId: productId,
      movementType: InventoryMovementType.purchase,
      quantityDelta: quantity,
      referenceType: 'purchase',
      userId: userId,
      notes: notes,
      createdAt: now,
    );

    await _database.transaction(() async {
      await _applyMovement(movement, now: now);
    });

    return movement;
  }

  /// Applies an already-created purchase movement locally.
  Future<void> applyPurchaseMovement(InventoryMovement movement) async {
    final now = DateTime.now();
    await _database.transaction(() async {
      await _applyMovement(movement, now: now);
    });
  }

  /// Applies sale movements for tracked products.
  ///
  /// Caller should own the surrounding transaction.
  Future<List<InventoryMovement>> applySaleMovements({
    required String saleId,
    required List<SaleItemModel> items,
    required String userId,
  }) async {
    final now = DateTime.now();
    final quantitiesByProduct = _quantitiesByProduct(items);
    final movements = <InventoryMovement>[];
    for (final entry in quantitiesByProduct.entries) {
      final product = await _product(entry.key);
      if (product == null || !product.tracksInventory) continue;

      final requested = entry.value;
      final stock = await _stockRow(product.id);
      final available = stock?.quantityOnHand ?? 0;
      if (available < requested) {
        throw InventoryStockException(
          productName: product.name,
          available: available,
          requested: requested,
        );
      }

      final movement = InventoryMovement(
        id: 'sale-$saleId-${product.id}',
        productId: product.id,
        movementType: InventoryMovementType.sale,
        quantityDelta: -requested,
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

  /// Applies inverse movements for a sale void. Caller should own transaction.
  Future<List<InventoryMovement>> applySaleVoidMovements({
    required String saleId,
    required List<SaleItemModel> items,
    required String userId,
  }) async {
    final now = DateTime.now();
    final quantitiesByProduct = _quantitiesByProduct(items);
    final movements = <InventoryMovement>[];
    for (final entry in quantitiesByProduct.entries) {
      final product = await _product(entry.key);
      if (product == null || !product.tracksInventory) continue;

      final movement = InventoryMovement(
        id: 'sale-void-$saleId-${product.id}',
        productId: product.id,
        movementType: InventoryMovementType.saleVoid,
        quantityDelta: entry.value,
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

  /// Returns movements by reference.
  Future<List<InventoryMovement>> getMovementsForReference({
    required String referenceType,
    required String referenceId,
  }) async {
    final rows =
        await (_database.select(_database.localInventoryMovements)
              ..where(
                (movement) =>
                    movement.referenceType.equals(referenceType) &
                    movement.referenceId.equals(referenceId),
              )
              ..orderBy([(movement) => OrderingTerm.asc(movement.createdAt)]))
            .get();

    return rows.map(_movementFromRow).toList();
  }

  Future<void> _applyMovement(
    InventoryMovement movement, {
    required DateTime now,
  }) async {
    final existing = await (_database.select(
      _database.localInventoryMovements,
    )..where((row) => row.id.equals(movement.id))).getSingleOrNull();
    if (existing != null) return;

    final stock = await _stockRow(movement.productId);
    final nextQuantity = (stock?.quantityOnHand ?? 0) + movement.quantityDelta;
    if (nextQuantity < 0) {
      final product = await _product(movement.productId);
      throw InventoryStockException(
        productName: product?.name ?? 'Producto',
        available: stock?.quantityOnHand ?? 0,
        requested: -movement.quantityDelta,
      );
    }

    await _database
        .into(_database.localInventoryMovements)
        .insert(
          LocalInventoryMovementsCompanion.insert(
            id: movement.id,
            productId: movement.productId,
            movementType: movement.typeValue,
            quantityDelta: movement.quantityDelta,
            referenceType: Value(movement.referenceType),
            referenceId: Value(movement.referenceId),
            userId: Value(movement.userId),
            notes: Value(movement.notes),
            syncStatus: const Value('pending'),
            createdAt: movement.createdAt,
            updatedAt: now,
          ),
        );

    await _database
        .into(_database.localInventoryStock)
        .insertOnConflictUpdate(
          LocalInventoryStockCompanion(
            productId: Value(movement.productId),
            quantityOnHand: Value(nextQuantity),
            syncStatus: const Value('pending'),
            createdAt: Value(stock?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<LocalInventoryStockData?> _stockRow(String productId) {
    return (_database.select(
      _database.localInventoryStock,
    )..where((row) => row.productId.equals(productId))).getSingleOrNull();
  }

  Future<LocalProduct?> _product(String productId) {
    return (_database.select(
      _database.localProducts,
    )..where((row) => row.id.equals(productId))).getSingleOrNull();
  }

  Map<String, int> _quantitiesByProduct(List<SaleItemModel> items) {
    final quantities = <String, int>{};
    for (final item in items) {
      quantities.update(
        item.productId,
        (value) => value + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    return quantities;
  }

  InventoryMovement _movementFromRow(LocalInventoryMovement row) {
    return InventoryMovement(
      id: row.id,
      productId: row.productId,
      movementType: switch (row.movementType) {
        'sale' => InventoryMovementType.sale,
        'sale_void' => InventoryMovementType.saleVoid,
        _ => InventoryMovementType.purchase,
      },
      quantityDelta: row.quantityDelta,
      referenceType: row.referenceType,
      referenceId: row.referenceId,
      userId: row.userId,
      notes: row.notes,
      createdAt: row.createdAt,
    );
  }
}
