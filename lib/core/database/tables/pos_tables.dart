import 'package:drift/drift.dart';

/// Local POS ticket lines that are open and not invoiced yet.
class LocalPosOpenTicketLines extends Table {
  /// Stable row identifier based on table and product/options.
  TextColumn get id => text()();

  /// Restaurant table that owns this open line.
  TextColumn get tableId => text()();

  /// Stable visual row identifier inside one table ticket.
  TextColumn get lineKey => text()
      .named('line_key')
      .withDefault(
        const Constant(''),
      )();

  /// Product selected in the POS.
  TextColumn get productId => text()();

  /// Selected modifier/options snapshot as JSON.
  TextColumn get selectedOptionsJson => text()();

  /// Current quantity in the open ticket.
  IntColumn get quantity => integer()();

  /// Whether this line has already been served.
  BoolColumn get isServed =>
      boolean().named('is_served').withDefault(const Constant(false))();

  /// Local creation date.
  DateTimeColumn get createdAt => dateTime()();

  /// Local last update date.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Open POS order metadata by table or no-table key.
class LocalPosOrderContexts extends Table {
  /// Table identifier or reserved no-table key.
  TextColumn get orderKey => text()();

  /// Selected sales type identifier.
  TextColumn get salesTypeId => text()();

  /// Local creation date.
  DateTimeColumn get createdAt => dateTime()();

  /// Local last update date.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {orderKey};
}

/// Local-only visual product ordering preferences for the POS grid.
class LocalPosProductOrderPreferences extends Table {
  /// Category where the order applies.
  TextColumn get categoryId => text()();

  /// Product shown in the category.
  TextColumn get productId => text()();

  /// Visual order inside the category.
  IntColumn get displayOrder => integer()();

  /// Last local update timestamp.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {categoryId, productId};
}

/// Local-only visual table ordering preferences for the POS table band.
class LocalPosTableOrderPreferences extends Table {
  /// Physical table shown in the POS band.
  TextColumn get tableId => text()();

  /// Visual order selected by the POS operator.
  IntColumn get displayOrder => integer()();

  /// Last local update timestamp.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {tableId};
}
