import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/tables/data/models/restaurant_table_model.dart';
import 'package:smoo_control/features/tables/data/models/table_account_model.dart';

/// Local datasource for restaurant tables.
final class LocalTablesDataSource {
  /// Creates a local tables datasource.
  const LocalTablesDataSource(this._database);

  final AppDatabase _database;

  /// Returns tables stored locally.
  Future<List<RestaurantTableModel>> getTables() async {
    final query = _database.select(_database.localRestaurantTables)
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    final rows = await query.get();

    return rows.map(RestaurantTableModel.fromLocal).toList();
  }

  /// Inserts or updates a local table.
  Future<RestaurantTableModel> saveTable(RestaurantTableModel table) async {
    final now = DateTime.now();

    await _database
        .into(_database.localRestaurantTables)
        .insertOnConflictUpdate(
          LocalRestaurantTablesCompanion(
            id: Value(table.id),
            name: Value(table.name),
            displayName: Value(table.displayName),
            status: Value(table.statusValue),
            isActive: Value(table.isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return table;
  }

  /// Updates only the local operational display name of a table.
  Future<RestaurantTableModel> saveTableDisplayName(
    RestaurantTableModel table,
  ) async {
    final now = DateTime.now();

    await (_database.update(
      _database.localRestaurantTables,
    )..where((row) => row.id.equals(table.id))).write(
      LocalRestaurantTablesCompanion(
        displayName: Value(table.displayName),
        updatedAt: Value(now),
      ),
    );

    return table;
  }

  /// Returns named accounts for a table.
  Future<List<TableAccountModel>> getTableAccounts(String tableId) async {
    final query = _database.select(_database.localTableAccounts)
      ..where((account) => account.tableId.equals(tableId))
      ..orderBy([(account) => OrderingTerm.asc(account.name)]);
    final rows = await query.get();

    return rows.map(TableAccountModel.fromLocal).toList();
  }

  /// Inserts or updates local table accounts.
  Future<List<TableAccountModel>> saveTableAccounts(
    List<TableAccountModel> accounts,
  ) async {
    final now = DateTime.now();

    await _database.batch((batch) {
      for (final account in accounts) {
        batch.insert(
          _database.localTableAccounts,
          LocalTableAccountsCompanion(
            id: Value(account.id),
            tableId: Value(account.tableId),
            name: Value(account.name),
            status: Value(account.statusValue),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    return accounts;
  }
}
