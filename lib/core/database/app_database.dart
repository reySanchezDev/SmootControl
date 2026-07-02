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
import 'package:smoo_control/core/database/tables/sync_tables.dart';
import 'package:smoo_control/core/database/tables/table_tables.dart';

part 'app_database.g.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the app database from a platform-specific executor.
  AppDatabase(super.e);

  @override
  int get schemaVersion => 22;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) => migrator.createAll(),
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(localBusinessSettings);
        }
        if (from < 3) {
          await migrator.addColumn(
            localSales,
            localSales.cashRegisterSessionId,
          );
        }
        if (from < 4) {
          await migrator.addColumn(
            localProducts,
            localProducts.isAvailableInPos,
          );
        }
        if (from < 5) {
          await migrator.addColumn(
            localProducts,
            localProducts.optionGroupsJson,
          );
          await migrator.addColumn(
            localSaleItems,
            localSaleItems.selectedOptionsLabel,
          );
        }
        if (from < 6) {
          await migrator.createTable(localRoles);
          await migrator.createTable(localPermissions);
          await migrator.createTable(localRolePermissions);
          await migrator.createTable(localUserProfiles);
        }
        if (from < 7) {
          await migrator.createTable(localAuditLogs);
        }
        if (from < 8) {
          await migrator.addColumn(
            localPaymentMethods,
            localPaymentMethods.groupName,
          );
          await migrator.addColumn(
            localPaymentMethods,
            localPaymentMethods.currencyCode,
          );
          await migrator.addColumn(
            localPaymentMethods,
            localPaymentMethods.displayOrder,
          );
          await customStatement(
            "UPDATE local_payment_methods SET group_name = 'Efectivo', "
            "currency_code = 'NIO' WHERE lower(name) LIKE '%efectivo%'",
          );
          await customStatement(
            "UPDATE local_payment_methods SET group_name = 'Tarjeta' "
            "WHERE lower(name) LIKE '%tarjeta%'",
          );
          await customStatement(
            "UPDATE local_payment_methods SET group_name = 'Transferencia' "
            "WHERE lower(name) LIKE '%transfer%'",
          );
        }
        if (from < 9) {
          await migrator.addColumn(
            localPaymentMethods,
            localPaymentMethods.parentId,
          );
          await migrator.addColumn(
            localPaymentMethods,
            localPaymentMethods.isPaymentTarget,
          );
        }
        if (from < 10) {
          await migrator.createTable(localModifierGroups);
          await migrator.createTable(localModifierOptions);
          await migrator.addColumn(
            localProducts,
            localProducts.modifierGroupIdsJson,
          );
        }
        if (from < 11) {
          await migrator.addColumn(
            localRestaurantTables,
            localRestaurantTables.displayName,
          );
        }
        if (from < 12) {
          await migrator.createTable(localPosOpenTicketLines);
        }
        if (from < 13) {
          await migrator.addColumn(
            localPosOpenTicketLines,
            localPosOpenTicketLines.lineKey,
          );
          await migrator.addColumn(
            localPosOpenTicketLines,
            localPosOpenTicketLines.isServed,
          );
        }
        if (from < 14) {
          await migrator.addColumn(
            localUserProfiles,
            localUserProfiles.pinSalt,
          );
          await migrator.addColumn(
            localUserProfiles,
            localUserProfiles.pinHash,
          );
        }
        if (from < 15) {
          await migrator.addColumn(
            localUserProfiles,
            localUserProfiles.isPosUser,
          );
        }
        if (from < 16) {
          await migrator.createTable(localExchangeRates);
        }
        if (from < 17) {
          await migrator.addColumn(
            localExpenseCategories,
            localExpenseCategories.parentId,
          );
        }
        if (from < 18) {
          await migrator.createTable(localSyncSettings);
        }
        if (from < 19) {
          await migrator.addColumn(
            localProducts,
            localProducts.tracksInventory,
          );
          await migrator.createTable(localInventoryStock);
          await migrator.createTable(localInventoryMovements);
        }
        if (from < 20) {
          await migrator.createTable(localDeviceState);
        }
        if (from < 21) {
          await migrator.createTable(localSalesTypes);
          await migrator.createTable(localPackagingItems);
          await migrator.createTable(localProductPackagingRules);
          await migrator.createTable(localPackagingStock);
          await migrator.createTable(localPackagingMovements);
          await migrator.createTable(localPosOrderContexts);
          await migrator.addColumn(localSales, localSales.salesTypeId);
          await migrator.addColumn(localSales, localSales.salesTypeName);
          final now = DateTime.now().toIso8601String();
          await customStatement(
            'INSERT OR IGNORE INTO local_sales_types '
            '(id, code, name, display_order, is_default, is_active, '
            'sync_status, created_at, updated_at) VALUES '
            "('11111111-1111-4111-8111-111111111111', "
            "'dine_in', 'Comer aqui', 0, 1, 1, "
            "'synced', '$now', '$now')",
          );
          await customStatement(
            'INSERT OR IGNORE INTO local_sales_types '
            '(id, code, name, display_order, is_default, is_active, '
            'sync_status, created_at, updated_at) VALUES '
            "('22222222-2222-4222-8222-222222222222', "
            "'to_go', 'Para llevar', 1, 0, 1, "
            "'synced', '$now', '$now')",
          );
        }
        if (from < 22) {
          await migrator.addColumn(
            localDeviceState,
            localDeviceState.syncDeviceId,
          );
          await migrator.addColumn(
            localDeviceState,
            localDeviceState.syncDeviceSecret,
          );
        }
      },
    );
  }
}
