import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/sync_columns.dart';

/// Local restaurant tables.
class LocalRestaurantTables extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Visible table name.
  TextColumn get name => text()();

  /// Temporary operational name shown in the POS.
  TextColumn get displayName => text().nullable()();

  /// available, occupied or disabled.
  TextColumn get status => text().withDefault(const Constant('available'))();

  /// Whether the table can be used.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Named split accounts that belong to a table.
class LocalTableAccounts extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Original table identifier.
  TextColumn get tableId => text()();

  /// Visible account or invoice name.
  TextColumn get name => text()();

  /// open, invoiced or voided.
  TextColumn get status => text().withDefault(const Constant('open'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
