import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/packaging/data/datasources/packaging_stock_exception.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_movement.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_stock_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/sales/data/models/sale_item_model.dart';
import 'package:uuid/uuid.dart';

/// Local datasource for sales types and packaging consumption.
final class LocalPackagingDataSource {
  /// Creates the datasource.
  const LocalPackagingDataSource(this._database, {Uuid uuid = const Uuid()})
    : _uuid = uuid;

  final AppDatabase _database;
  final Uuid _uuid;

  /// Returns configured sales types.
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

  /// Returns current stock for packaging items.
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
