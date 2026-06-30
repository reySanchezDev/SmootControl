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
