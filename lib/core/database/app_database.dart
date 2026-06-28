import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/access_control_tables.dart';
import 'package:smoo_control/core/database/tables/audit_tables.dart';
import 'package:smoo_control/core/database/tables/cash_expense_tables.dart';
import 'package:smoo_control/core/database/tables/catalog_tables.dart';
import 'package:smoo_control/core/database/tables/exchange_rate_tables.dart';
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
    LocalModifierGroups,
    LocalModifierOptions,
    LocalPaymentMethods,
    LocalPosOpenTicketLines,
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
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the app database from a platform-specific executor.
  AppDatabase(super.e);

  @override
  int get schemaVersion => 17;

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
      },
    );
  }
}
