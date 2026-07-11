part of 'pilot_operation_reset_service.dart';

extension _PilotOperationResetLocal on PilotOperationResetService {
  Future<int> _resetLocal() {
    return _database.transaction(() async {
      final rowsBefore = await _countOperationalRows();
      final now = DateTime.now();

      await _database.delete(_database.localSyncQueue).go();
      await _database.delete(_database.localPosOpenTicketLines).go();
      await _database.delete(_database.localPosOrderContexts).go();
      await _database.delete(_database.localSaleVoids).go();
      await _database.delete(_database.localSaleItems).go();
      await _database.delete(_database.localSales).go();
      await _database.delete(_database.localOperatingExpenses).go();
      await _database.delete(_database.localTableAccounts).go();
      await _database.delete(_database.localCashRegisterSessions).go();
      await _database.delete(_database.localInventoryMovements).go();
      await _database.delete(_database.localPackagingMovements).go();
      await _database.delete(_database.localSalaryAdvances).go();

      await _database
          .update(_database.localInventoryStock)
          .write(
            LocalInventoryStockCompanion(
              quantityOnHand: const Value(0),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
          );
      await _database
          .update(_database.localPackagingStock)
          .write(
            LocalPackagingStockCompanion(
              quantityOnHand: const Value(0),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
          );
      await _database
          .update(_database.localRestaurantTables)
          .write(
            LocalRestaurantTablesCompanion(
              status: const Value('available'),
              displayName: const Value(null),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
          );

      final settings = await _database
          .select(_database.localBusinessSettings)
          .getSingleOrNull();
      if (settings != null) {
        await (_database.update(
          _database.localBusinessSettings,
        )..where((table) => table.id.equals(settings.id))).write(
          LocalBusinessSettingsCompanion(
            nextInvoiceNumber: Value(settings.initialInvoiceNumber),
            syncStatus: const Value('synced'),
            syncError: const Value(null),
            updatedAt: Value(now),
            syncedAt: Value(now),
          ),
        );
      }

      return rowsBefore;
    });
  }

  Future<int> _resetLocalScope(PilotCleanupScope scope) {
    return _database.transaction(() async {
      return switch (scope) {
        PilotCleanupScope.sales => _resetLocalSales(),
        PilotCleanupScope.expenses => _resetLocalExpenses(),
        PilotCleanupScope.salaryAdvances => _resetLocalSalaryAdvances(),
        PilotCleanupScope.payroll => Future.value(0),
        PilotCleanupScope.staffConsumptions => _resetLocalStaffConsumptions(),
        PilotCleanupScope.staffOperations => _resetLocalStaffOperations(),
      };
    });
  }

  Future<int> _resetLocalSales() async {
    var rows = 0;
    rows += await _countLocalSalesByKind('sale');
    rows += await _count(
      'local_sale_items WHERE sale_id IN '
      "(SELECT id FROM local_sales WHERE sale_kind = 'sale')",
    );
    rows += await _count('local_sale_voids');
    rows += await _count(
      "local_inventory_movements WHERE reference_type IN ('sale', 'sale_void')",
    );
    rows += await _count(
      "local_packaging_movements WHERE reference_type IN ('sale', 'sale_void')",
    );
    rows += await _count('local_table_accounts');
    rows += await _count('local_pos_open_ticket_lines');
    rows += await _count('local_pos_order_contexts');
    rows += await _count(
      "local_sync_queue WHERE entity_type = 'sales' "
      "AND payload_json NOT LIKE '%staff_consumption%'",
    );

    await _reverseLocalInventoryMovements(
      "reference_type IN ('sale', 'sale_void')",
    );
    await _reverseLocalPackagingMovements(
      "reference_type IN ('sale', 'sale_void')",
    );

    await _delete(
      'local_sale_voids',
      where:
          'sale_id IN (SELECT id FROM local_sales WHERE sale_kind = '
          "'sale')",
    );
    await _delete(
      'local_sale_items',
      where:
          'sale_id IN (SELECT id FROM local_sales WHERE sale_kind = '
          "'sale')",
    );
    await _delete('local_sales', where: "sale_kind = 'sale'");
    await _delete(
      'local_inventory_movements',
      where: "reference_type IN ('sale', 'sale_void')",
    );
    await _delete(
      'local_packaging_movements',
      where: "reference_type IN ('sale', 'sale_void')",
    );
    await _delete('local_table_accounts');
    await _delete('local_pos_open_ticket_lines');
    await _delete('local_pos_order_contexts');
    await _delete(
      'local_sync_queue',
      where:
          "entity_type = 'sales' "
          "AND payload_json NOT LIKE '%staff_consumption%'",
    );

    if (await _count('local_operating_expenses') == 0 &&
        await _count('local_salary_advances') == 0) {
      rows += await _count('local_cash_register_sessions');
      await _delete('local_cash_register_sessions');
      await _delete(
        'local_sync_queue',
        where: "entity_type = 'cash_register_sessions'",
      );
    }

    final now = DateTime.now();
    await _database
        .update(_database.localRestaurantTables)
        .write(
          LocalRestaurantTablesCompanion(
            status: const Value('available'),
            displayName: const Value(null),
            syncStatus: const Value('synced'),
            syncError: const Value(null),
            updatedAt: Value(now),
            syncedAt: Value(now),
          ),
        );
    await _resetLocalInvoiceCursor(now);
    return rows;
  }

  Future<int> _resetLocalExpenses() async {
    var rows = 0;
    rows += await _count(
      "local_operating_expenses WHERE expense_kind = 'operational'",
    );
    rows += await _count(
      "local_sync_queue WHERE entity_type = 'operating_expenses' "
      "AND payload_json NOT LIKE '%salary_advance%'",
    );
    await _delete(
      'local_operating_expenses',
      where: "expense_kind = 'operational'",
    );
    await _delete(
      'local_sync_queue',
      where:
          "entity_type = 'operating_expenses' "
          "AND payload_json NOT LIKE '%salary_advance%'",
    );
    return rows;
  }

  Future<int> _resetLocalSalaryAdvances() async {
    var rows = 0;
    rows += await _count('local_salary_advances');
    rows += await _count(
      "local_operating_expenses WHERE expense_kind = 'salary_advance'",
    );
    rows += await _count(
      "local_sync_queue WHERE entity_type = 'salary_advances' "
      "OR (entity_type = 'operating_expenses' "
      "AND payload_json LIKE '%salary_advance%')",
    );
    await _delete('local_salary_advances');
    await _delete(
      'local_operating_expenses',
      where: "expense_kind = 'salary_advance'",
    );
    await _delete(
      'local_sync_queue',
      where:
          "entity_type = 'salary_advances' "
          "OR (entity_type = 'operating_expenses' "
          "AND payload_json LIKE '%salary_advance%')",
    );
    return rows;
  }

  Future<int> _resetLocalStaffConsumptions() async {
    var rows = 0;
    rows += await _countLocalSalesByKind('staff_consumption');
    rows += await _count(
      'local_sale_items WHERE sale_id IN '
      "(SELECT id FROM local_sales WHERE sale_kind = 'staff_consumption')",
    );
    rows += await _count(
      "local_inventory_movements WHERE reference_type = 'staff_consumption'",
    );
    rows += await _count(
      "local_packaging_movements WHERE reference_type = 'staff_consumption'",
    );
    rows += await _count(
      "local_sync_queue WHERE entity_type = 'sales' "
      "AND payload_json LIKE '%staff_consumption%'",
    );

    await _reverseLocalInventoryMovements(
      "reference_type = 'staff_consumption'",
    );
    await _reverseLocalPackagingMovements(
      "reference_type = 'staff_consumption'",
    );
    await _delete(
      'local_sale_items',
      where:
          'sale_id IN (SELECT id FROM local_sales WHERE sale_kind = '
          "'staff_consumption')",
    );
    await _delete(
      'local_sales',
      where: "sale_kind = 'staff_consumption'",
    );
    await _delete(
      'local_inventory_movements',
      where: "reference_type = 'staff_consumption'",
    );
    await _delete(
      'local_packaging_movements',
      where: "reference_type = 'staff_consumption'",
    );
    await _delete(
      'local_sync_queue',
      where:
          "entity_type = 'sales' "
          "AND payload_json LIKE '%staff_consumption%'",
    );
    return rows;
  }

  Future<int> _resetLocalStaffOperations() async {
    var rows = 0;
    rows += await _resetLocalStaffConsumptions();
    rows += await _resetLocalSalaryAdvances();
    return rows;
  }
}
