part of 'supabase_catalog_pull_service.dart';

extension on SupabaseCatalogPullService {
  Future<void> _applyPaymentMethods(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'payment_methods');
      remoteIds.add(id);
      await _database
          .into(_database.localPaymentMethods)
          .insert(
            LocalPaymentMethodsCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Metodo')),
              parentId: Value(_optionalText(row['parent_id'])),
              groupName: Value(_text(row['group_name'], defaultValue: 'Otros')),
              currencyCode: Value(_optionalText(row['currency_code'])),
              displayOrder: Value(_int(row['display_order'])),
              isPaymentTarget: Value(
                _bool(row['is_payment_target'], defaultValue: true),
              ),
              affectsCashRegister: Value(
                _bool(row['affects_cash']),
              ),
              requiresReference: Value(_bool(row['requires_reference'])),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await _markMissingPaymentMethodsInactive(remoteIds, now);
  }

  Future<void> _applyTables(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'restaurant_tables');
      final existing = await (_database.select(
        _database.localRestaurantTables,
      )..where((table) => table.id.equals(id))).getSingleOrNull();
      remoteIds.add(id);
      await _database
          .into(_database.localRestaurantTables)
          .insert(
            LocalRestaurantTablesCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Mesa')),
              displayName: Value(
                existing?.displayName ?? _optionalText(row['display_name']),
              ),
              status: Value(
                existing?.status ??
                    _text(row['status'], defaultValue: 'available'),
              ),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await _markMissingTablesInactive(remoteIds, now);
  }

  Future<void> _applyExpenseCategories(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'expense_categories');
      final parentId = _optionalText(row['parent_id']);
      remoteIds.add(id);
      await _database
          .into(_database.localExpenseCategories)
          .insert(
            LocalExpenseCategoriesCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Gasto')),
              parentId: Value(parentId),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              includeInGrossProfitCoverage: Value(
                parentId == null &&
                    _bool(
                      row['include_in_gross_profit_coverage'],
                    ),
              ),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await _markMissingExpenseCategoriesInactive(remoteIds, now);
  }

  Future<void> _applyExchangeRates(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    for (final row in rows) {
      final currencyCode = _optionalText(row['currency_code']);
      final businessDate = _date(row['business_date']);
      if (currencyCode == null || businessDate == null) continue;
      await _database
          .into(_database.localExchangeRates)
          .insert(
            LocalExchangeRatesCompanion(
              currencyCode: Value(currencyCode),
              businessDate: Value(businessDate),
              rateInCents: Value(_moneyCents(row['rate'])),
              remoteId: Value('$currencyCode-${_dateKey(businessDate)}'),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _applyCashRegisterSessions(
    List<Map<String, Object?>> rows,
  ) async {
    final now = DateTime.now();
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'cash_register_sessions');
      final cashierId = _optionalText(row['cashier_user_id']);
      final businessDate = _date(row['business_date']);
      if (cashierId == null || businessDate == null) continue;

      final existing = await (_database.select(
        _database.localCashRegisterSessions,
      )..where((session) => session.id.equals(id))).getSingleOrNull();

      await _database
          .into(_database.localCashRegisterSessions)
          .insert(
            LocalCashRegisterSessionsCompanion(
              id: Value(id),
              cashierId: Value(cashierId),
              businessDate: Value(BusinessDateFormatter.format(businessDate)),
              openingCashInCents: Value(
                _moneyCents(row['opening_cash_amount']),
              ),
              physicalClosingCashInCents: Value(
                row['counted_cash_amount'] == null
                    ? null
                    : _moneyCents(row['counted_cash_amount']),
              ),
              status: Value(_text(row['status'], defaultValue: 'open')),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }
}
