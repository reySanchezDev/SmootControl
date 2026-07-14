part of 'app_database.dart';

extension _AppDatabaseMigrations on AppDatabase {
  Future<void> _upgradeSchema(Migrator migrator, int from) async {
    if (from < 2) {
      await migrator.createTable(localBusinessSettings);
    }
    if (from < 3) {
      await migrator.addColumn(localSales, localSales.cashRegisterSessionId);
    }
    if (from < 4) {
      await migrator.addColumn(localProducts, localProducts.isAvailableInPos);
    }
    if (from < 5) {
      await migrator.addColumn(localProducts, localProducts.optionGroupsJson);
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
    await _upgradeSchemaFrom7To20(migrator, from);
    await _upgradeSchemaFrom21To24(migrator, from);
    await _upgradeSchemaFrom25To28(migrator, from);
    await _upgradeSchemaFrom29(migrator, from);
    await _upgradeSchemaFrom30(migrator, from);
  }

  Future<void> _upgradeSchemaFrom7To20(Migrator migrator, int from) async {
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
      await migrator.addColumn(localUserProfiles, localUserProfiles.pinSalt);
      await migrator.addColumn(localUserProfiles, localUserProfiles.pinHash);
    }
    if (from < 15) {
      await migrator.addColumn(localUserProfiles, localUserProfiles.isPosUser);
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
      await migrator.addColumn(localProducts, localProducts.tracksInventory);
      await migrator.createTable(localInventoryStock);
      await migrator.createTable(localInventoryMovements);
    }
    if (from < 20) {
      await migrator.createTable(localDeviceState);
    }
  }

  Future<void> _upgradeSchemaFrom21To24(Migrator migrator, int from) async {
    if (from < 21) {
      await _createPackagingAndSalesTypeTables(migrator);
      await _addSalesTypeColumnsIfMissing(migrator);
      await _seedDefaultSalesTypes();
    }
    if (from < 22) {
      await _addDeviceSyncColumnsIfMissing(migrator);
    }
    if (from < 23) {
      if (!await _tableExists(
        localPosProductOrderPreferences.actualTableName,
      )) {
        await migrator.createTable(localPosProductOrderPreferences);
      }
    }
    if (from < 24) {
      await _createStaffTablesIfMissing(migrator);
      await _addStaffSaleColumnsIfMissing(migrator);
      await _addStaffExpenseColumnsIfMissing(migrator);
      await _seedSalaryAdvanceRuleAndExpenseCategory();
    }
  }

  Future<void> _upgradeSchemaFrom25To28(Migrator migrator, int from) async {
    if (from < 25) {
      if (!await _columnExists(
        localSalaryAdvances.actualTableName,
        localSalaryAdvances.deliveredAt.$name,
      )) {
        await migrator.addColumn(
          localSalaryAdvances,
          localSalaryAdvances.deliveredAt,
        );
      }
    }
    if (from < 26) {
      if (!await _tableExists(localPosTableOrderPreferences.actualTableName)) {
        await migrator.createTable(localPosTableOrderPreferences);
      }
    }
    if (from < 27) {
      await customStatement(
        'UPDATE local_expense_categories '
        "SET is_active = 0, updated_at = datetime('now'), "
        "synced_at = datetime('now'), sync_status = 'synced' "
        "WHERE id = '33333333-3333-4333-8333-333333333333'",
      );
    }
    if (from < 28) {
      if (!await _columnExists(
        localExpenseCategories.actualTableName,
        localExpenseCategories.includeInGrossProfitCoverage.$name,
      )) {
        await migrator.addColumn(
          localExpenseCategories,
          localExpenseCategories.includeInGrossProfitCoverage,
        );
      }
    }
  }

  Future<void> _upgradeSchemaFrom29(Migrator migrator, int from) async {
    if (from < 29) {
      await _addExpenseCoverageProjectionColumns(migrator);
      await _moveExpenseCoverageToChildren();
    }
  }

  Future<void> _upgradeSchemaFrom30(Migrator migrator, int from) async {
    if (from < 30) {
      if (await _tableExists(localProducts.actualTableName) &&
          !await _columnExists(
            localProducts.actualTableName,
            localProducts.isRawMaterial.$name,
          )) {
        await migrator.addColumn(localProducts, localProducts.isRawMaterial);
      }
    }
  }
}
