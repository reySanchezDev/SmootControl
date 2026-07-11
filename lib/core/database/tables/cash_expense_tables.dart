import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/sync_columns.dart';

/// Local daily cash register sessions.
class LocalCashRegisterSessions extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Cashier user identifier.
  TextColumn get cashierId => text()();

  /// Business date as yyyy-MM-dd.
  TextColumn get businessDate => text()();

  /// Starting cash in minor currency units.
  IntColumn get openingCashInCents => integer()();

  /// Physical closing cash in minor currency units.
  IntColumn get physicalClosingCashInCents => integer().nullable()();

  /// open or closed.
  TextColumn get status => text().withDefault(const Constant('open'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local operational expense categories.
class LocalExpenseCategories extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Visible category name.
  TextColumn get name => text()();

  /// Parent category used to group expense concepts.
  TextColumn get parentId => text().nullable()();

  /// Whether the category can be used.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Whether this category subtracts from gross profit coverage reports.
  BoolColumn get includeInGrossProfitCoverage =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local operational expenses.
class LocalOperatingExpenses extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Expense category identifier.
  TextColumn get categoryId => text()();

  /// Cash register session identifier when paid from cash.
  TextColumn get cashRegisterSessionId => text().nullable()();

  /// operational or salary_advance.
  TextColumn get expenseKind =>
      text().withDefault(const Constant('operational'))();

  /// Employee linked to salary advances.
  TextColumn get employeeId => text().nullable()();

  /// Whether this row affected POS cash.
  BoolColumn get affectsCash => boolean().withDefault(const Constant(true))();

  /// Amount in minor currency units.
  IntColumn get amountInCents => integer()();

  /// Expense description.
  TextColumn get description => text()();

  /// User that registered the expense.
  TextColumn get createdBy => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
