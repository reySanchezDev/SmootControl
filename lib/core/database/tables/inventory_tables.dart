import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/sync_columns.dart';

/// Current local stock by product.
class LocalInventoryStock extends Table with SyncColumns {
  /// Product identifier.
  TextColumn get productId => text()();

  /// Current stock quantity.
  IntColumn get quantityOnHand => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {productId};
}

/// Auditable stock movements.
class LocalInventoryMovements extends Table with SyncColumns {
  /// Stable movement identifier.
  TextColumn get id => text()();

  /// Product affected by the movement.
  TextColumn get productId => text()();

  /// purchase, sale or sale_void.
  TextColumn get movementType => text()();

  /// Signed movement quantity.
  IntColumn get quantityDelta => integer()();

  /// Origin kind, for example sale or purchase.
  TextColumn get referenceType => text().nullable()();

  /// Origin row identifier.
  TextColumn get referenceId => text().nullable()();

  /// User who generated the movement.
  TextColumn get userId => text().nullable()();

  /// Optional operation note.
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Current local stock by packaging item.
class LocalPackagingStock extends Table with SyncColumns {
  /// Packaging identifier.
  TextColumn get packagingItemId => text()();

  /// Current stock quantity.
  IntColumn get quantityOnHand => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {packagingItemId};
}

/// Auditable packaging stock movements.
class LocalPackagingMovements extends Table with SyncColumns {
  /// Stable movement identifier.
  TextColumn get id => text()();

  /// Packaging affected by the movement.
  TextColumn get packagingItemId => text()();

  /// packaging_purchase, packaging_sale or packaging_sale_void.
  TextColumn get movementType => text()();

  /// Signed movement quantity.
  IntColumn get quantityDelta => integer()();

  /// Historical unit cost in minor currency units.
  IntColumn get unitCostInCents => integer().withDefault(const Constant(0))();

  /// Origin kind, for example sale or purchase.
  TextColumn get referenceType => text().nullable()();

  /// Origin row identifier.
  TextColumn get referenceId => text().nullable()();

  /// User who generated the movement.
  TextColumn get userId => text().nullable()();

  /// Optional operation note.
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
