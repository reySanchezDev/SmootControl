part of 'app_database.dart';

extension _AppDatabaseMigrationHelpers on AppDatabase {
  Future<void> _createPackagingAndSalesTypeTables(Migrator migrator) async {
    if (!await _tableExists(localSalesTypes.actualTableName)) {
      await migrator.createTable(localSalesTypes);
    }
    if (!await _tableExists(localPackagingItems.actualTableName)) {
      await migrator.createTable(localPackagingItems);
    }
    if (!await _tableExists(localProductPackagingRules.actualTableName)) {
      await migrator.createTable(localProductPackagingRules);
    }
    if (!await _tableExists(localPackagingStock.actualTableName)) {
      await migrator.createTable(localPackagingStock);
    }
    if (!await _tableExists(localPackagingMovements.actualTableName)) {
      await migrator.createTable(localPackagingMovements);
    }
    if (!await _tableExists(localPosOrderContexts.actualTableName)) {
      await migrator.createTable(localPosOrderContexts);
    }
  }

  Future<void> _addSalesTypeColumnsIfMissing(Migrator migrator) async {
    if (!await _columnExists(
      localSales.actualTableName,
      localSales.salesTypeId.$name,
    )) {
      await migrator.addColumn(localSales, localSales.salesTypeId);
    }
    if (!await _columnExists(
      localSales.actualTableName,
      localSales.salesTypeName.$name,
    )) {
      await migrator.addColumn(localSales, localSales.salesTypeName);
    }
  }

  Future<void> _seedDefaultSalesTypes() async {
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

  Future<void> _addDeviceSyncColumnsIfMissing(Migrator migrator) async {
    if (!await _columnExists(
      localDeviceState.actualTableName,
      localDeviceState.syncDeviceId.$name,
    )) {
      await migrator.addColumn(localDeviceState, localDeviceState.syncDeviceId);
    }
    if (!await _columnExists(
      localDeviceState.actualTableName,
      localDeviceState.syncDeviceSecret.$name,
    )) {
      await migrator.addColumn(
        localDeviceState,
        localDeviceState.syncDeviceSecret,
      );
    }
  }

  Future<void> _createStaffTablesIfMissing(Migrator migrator) async {
    if (!await _tableExists(localEmployees.actualTableName)) {
      await migrator.createTable(localEmployees);
    }
    if (!await _tableExists(localBusinessRules.actualTableName)) {
      await migrator.createTable(localBusinessRules);
    }
    if (!await _tableExists(localSalaryAdvances.actualTableName)) {
      await migrator.createTable(localSalaryAdvances);
    }
  }

  Future<void> _addStaffSaleColumnsIfMissing(Migrator migrator) async {
    if (!await _columnExists(
      localSales.actualTableName,
      localSales.saleKind.$name,
    )) {
      await migrator.addColumn(localSales, localSales.saleKind);
    }
    if (!await _columnExists(
      localSales.actualTableName,
      localSales.employeeId.$name,
    )) {
      await migrator.addColumn(localSales, localSales.employeeId);
    }
    if (!await _columnExists(
      localSales.actualTableName,
      localSales.internalReceiptNumber.$name,
    )) {
      await migrator.addColumn(localSales, localSales.internalReceiptNumber);
    }
    if (!await _columnExists(
      localSales.actualTableName,
      localSales.payrollRunId.$name,
    )) {
      await migrator.addColumn(localSales, localSales.payrollRunId);
    }
  }

  Future<void> _addStaffExpenseColumnsIfMissing(Migrator migrator) async {
    if (!await _columnExists(
      localOperatingExpenses.actualTableName,
      localOperatingExpenses.expenseKind.$name,
    )) {
      await migrator.addColumn(
        localOperatingExpenses,
        localOperatingExpenses.expenseKind,
      );
    }
    if (!await _columnExists(
      localOperatingExpenses.actualTableName,
      localOperatingExpenses.employeeId.$name,
    )) {
      await migrator.addColumn(
        localOperatingExpenses,
        localOperatingExpenses.employeeId,
      );
    }
    if (!await _columnExists(
      localOperatingExpenses.actualTableName,
      localOperatingExpenses.affectsCash.$name,
    )) {
      await migrator.addColumn(
        localOperatingExpenses,
        localOperatingExpenses.affectsCash,
      );
    }
  }

  Future<void> _seedSalaryAdvanceRuleAndExpenseCategory() async {
    await customStatement(
      'INSERT OR IGNORE INTO local_business_rules '
      '(key, bool_value, sync_status, created_at, updated_at) VALUES '
      "('salary_advance_pos_affects_cash', 0, 'synced', "
      "datetime('now'), datetime('now'))",
    );
    await customStatement(
      'INSERT OR IGNORE INTO local_expense_categories '
      '(id, name, parent_id, is_active, sync_status, created_at, updated_at) '
      'VALUES '
      "('33333333-3333-4333-8333-333333333333', "
      "'Adelantos de salario', NULL, 1, 'synced', "
      "datetime('now'), datetime('now'))",
    );
  }
}
