part of 'pilot_operation_reset_service.dart';

extension _PilotOperationResetSql on PilotOperationResetService {
  Future<void> _reverseLocalInventoryMovements(String where) async {
    await _database.customUpdate(
      'UPDATE local_inventory_stock '
      'SET quantity_on_hand = MAX(quantity_on_hand - COALESCE(( '
      'SELECT SUM(quantity_delta) FROM local_inventory_movements movement '
      'WHERE movement.product_id = local_inventory_stock.product_id '
      'AND $where '
      '), 0), 0), updated_at = ?, synced_at = ?, sync_status = ? '
      'WHERE product_id IN ( '
      'SELECT product_id FROM local_inventory_movements WHERE $where '
      ')',
      variables: [
        Variable<DateTime>(DateTime.now()),
        Variable<DateTime>(DateTime.now()),
        const Variable<String>('synced'),
      ],
      updates: {_database.localInventoryStock},
    );
  }

  Future<void> _reverseLocalPackagingMovements(String where) async {
    await _database.customUpdate(
      'UPDATE local_packaging_stock '
      'SET quantity_on_hand = MAX(quantity_on_hand - COALESCE(( '
      'SELECT SUM(quantity_delta) FROM local_packaging_movements movement '
      'WHERE movement.packaging_item_id = '
      'local_packaging_stock.packaging_item_id '
      'AND $where '
      '), 0), 0), updated_at = ?, synced_at = ?, sync_status = ? '
      'WHERE packaging_item_id IN ( '
      'SELECT packaging_item_id FROM local_packaging_movements WHERE $where '
      ')',
      variables: [
        Variable<DateTime>(DateTime.now()),
        Variable<DateTime>(DateTime.now()),
        const Variable<String>('synced'),
      ],
      updates: {_database.localPackagingStock},
    );
  }

  Future<void> _resetLocalInvoiceCursor(DateTime now) async {
    final settings = await _database
        .select(_database.localBusinessSettings)
        .getSingleOrNull();
    if (settings == null) return;
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

  Future<int> _delete(String tableName, {String? where}) {
    final statement = where == null
        ? 'DELETE FROM $tableName'
        : 'DELETE FROM $tableName WHERE $where';
    return _database.customUpdate(statement);
  }

  Future<int> _countOperationalRows() async {
    var total = 0;
    for (final table in _operationalTables) {
      total += await _count(table);
    }
    return total;
  }

  Future<int> _countLocalSalesByKind(String saleKind) {
    return _count("local_sales WHERE sale_kind = '$saleKind'");
  }

  Future<int> _count(String tableName) async {
    final row = await _database
        .customSelect('SELECT COUNT(*) AS row_count FROM $tableName')
        .getSingle();
    return _int(row.data['row_count']);
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

const _operationalTables = [
  'local_sync_queue',
  'local_pos_open_ticket_lines',
  'local_pos_order_contexts',
  'local_sale_voids',
  'local_sale_items',
  'local_sales',
  'local_operating_expenses',
  'local_table_accounts',
  'local_cash_register_sessions',
  'local_inventory_movements',
  'local_packaging_movements',
  'local_salary_advances',
];
