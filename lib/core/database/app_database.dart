import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/access_control_tables.dart';
import 'package:smoo_control/core/database/tables/audit_tables.dart';
import 'package:smoo_control/core/database/tables/cash_expense_tables.dart';
import 'package:smoo_control/core/database/tables/catalog_tables.dart';
import 'package:smoo_control/core/database/tables/device_state_tables.dart';
import 'package:smoo_control/core/database/tables/exchange_rate_tables.dart';
import 'package:smoo_control/core/database/tables/inventory_tables.dart';
import 'package:smoo_control/core/database/tables/pos_tables.dart';
import 'package:smoo_control/core/database/tables/sales_tables.dart';
import 'package:smoo_control/core/database/tables/settings_tables.dart';
import 'package:smoo_control/core/database/tables/staff_tables.dart';
import 'package:smoo_control/core/database/tables/sync_tables.dart';
import 'package:smoo_control/core/database/tables/table_tables.dart';

part 'app_database.g.dart';
part 'app_database_migrations.dart';
part 'app_database_migration_helpers.dart';

/// Local Drift database used for offline-first persistence.
@DriftDatabase(
  tables: [
    LocalProductCategories,
    LocalProducts,
    LocalSalesTypes,
    LocalPackagingItems,
    LocalProductPackagingRules,
    LocalModifierGroups,
    LocalModifierOptions,
    LocalPaymentMethods,
    LocalInventoryStock,
    LocalInventoryMovements,
    LocalPackagingStock,
    LocalPackagingMovements,
    LocalPosOpenTicketLines,
    LocalPosOrderContexts,
    LocalPosProductOrderPreferences,
    LocalPosTableOrderPreferences,
    LocalRestaurantTables,
    LocalTableAccounts,
    LocalSales,
    LocalSaleItems,
    LocalSaleVoids,
    LocalCashRegisterSessions,
    LocalExpenseCategories,
    LocalOperatingExpenses,
    LocalBusinessSettings,
    LocalExchangeRates,
    LocalSyncQueue,
    LocalRoles,
    LocalPermissions,
    LocalRolePermissions,
    LocalUserProfiles,
    LocalAuditLogs,
    LocalSyncSettings,
    LocalDeviceState,
    LocalEmployees,
    LocalBusinessRules,
    LocalSalaryAdvances,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the app database from a platform-specific executor.
  AppDatabase(super.e);

  @override
  int get schemaVersion => 28;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) => migrator.createAll(),
      onUpgrade: (migrator, from, to) => _upgradeSchema(migrator, from),
    );
  }

  Future<bool> _tableExists(String tableName) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      variables: [Variable<String>(tableName)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    return rows.any((row) => row.data['name'] == columnName);
  }
}
