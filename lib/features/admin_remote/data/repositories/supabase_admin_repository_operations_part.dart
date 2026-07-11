part of 'supabase_admin_repository.dart';

mixin _SupabaseAdminOperationsMixin on _SupabaseAdminRepositoryBase
    implements
        IPaymentMethodsRepository,
        ITablesRepository,
        IExchangeRateRepository {
  @override
  Future<AppResult<List<PaymentMethod>>> getPaymentMethods() async {
    return _guard(
      'payment_methods_read_failed',
      'No se pudieron leer metodos de pago.',
      () async {
        final rows = await _getRows('payment_methods', {
          'or': '(restaurant_id.is.null,restaurant_id.eq.$_restaurantId)',
          'select': '*',
          'order': 'display_order.asc,name.asc',
        });
        return rows.map(_paymentMethodFromRow).toList();
      },
    );
  }

  @override
  Future<AppResult<PaymentMethod>> savePaymentMethod(
    PaymentMethod method,
  ) async {
    return _guard(
      'payment_method_save_failed',
      'No se pudo guardar metodo de pago.',
      () async {
        await _upsert('payment_methods', {
          'id': method.id,
          'restaurant_id': _restaurantId,
          'name': method.name,
          'parent_id': method.parentId,
          'group_name': method.groupName,
          'currency_code': method.currencyCode,
          'display_order': method.displayOrder,
          'is_payment_target': method.isPaymentTarget,
          'affects_cash': method.affectsCashRegister,
          'requires_reference': method.requiresReference,
          'is_active': method.isActive,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return method;
      },
    );
  }

  @override
  Future<AppResult<PaymentMethod>> removePaymentMethodLevel(
    PaymentMethod method,
  ) async {
    return _guard(
      'payment_method_remove_failed',
      'No se pudo remover metodo de pago.',
      () async {
        final now = DateTime.now().toIso8601String();
        await _patchWhere(
          'payment_methods',
          {'parent_id': method.parentId, 'updated_at': now},
          {'parent_id': 'eq.${method.id}'},
        );
        await _deleteWhere('payment_methods', {'id': 'eq.${method.id}'});
        return method;
      },
    );
  }

  @override
  Future<AppResult<List<RestaurantTable>>> getTables() async {
    return _guard('tables_read_failed', 'No se pudieron leer mesas.', () async {
      final rows = await _getRows('restaurant_tables', {
        'restaurant_id': 'eq.$_restaurantId',
        'select': '*',
        'order': 'name.asc',
      });
      return rows.map(_restaurantTableFromRow).toList();
    });
  }

  @override
  Future<AppResult<RestaurantTable>> saveTable(RestaurantTable table) async {
    return _guard('table_save_failed', 'No se pudo guardar mesa.', () async {
      await _upsert('restaurant_tables', {
        'id': table.id,
        'restaurant_id': _restaurantId,
        'name': table.name,
        'display_name': table.displayName,
        'status': table.status.name,
        'is_active': table.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return table;
    });
  }

  @override
  Future<AppResult<RestaurantTable>> saveTableDisplayName(
    RestaurantTable table,
  ) {
    return saveTable(table);
  }

  @override
  Future<AppResult<List<TableAccount>>> getTableAccounts(String tableId) async {
    return _guard(
      'table_accounts_read_failed',
      'No se pudieron leer cuentas de mesa.',
      () async {
        final rows = await _getRows('table_accounts', {
          'restaurant_id': 'eq.$_restaurantId',
          'table_id': 'eq.$tableId',
          'select': '*',
          'order': 'updated_at.asc',
        });
        return rows.map(_tableAccountFromRow).toList();
      },
    );
  }

  @override
  Future<AppResult<List<TableAccount>>> saveTableAccounts(
    List<TableAccount> accounts,
  ) async {
    return _guard(
      'table_accounts_save_failed',
      'No se pudieron guardar cuentas de mesa.',
      () async {
        for (final account in accounts) {
          await _upsert('table_accounts', {
            'id': account.id,
            'restaurant_id': _restaurantId,
            'table_id': account.tableId,
            'name': account.name,
            'status': account.status.name,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
        return accounts;
      },
    );
  }

  @override
  Future<AppResult<List<ExchangeRate>>> getRatesForMonth({
    required String currencyCode,
    required DateTime month,
  }) async {
    return _guard(
      'exchange_rates_read_failed',
      'No se pudieron leer tasas de cambio.',
      () async {
        final start = DateTime(month.year, month.month);
        final end = DateTime(month.year, month.month + 1);
        final rows = await _getRows('exchange_rates', {
          'restaurant_id': 'eq.$_restaurantId',
          'currency_code': 'eq.$currencyCode',
          'business_date': 'gte.${_dateOnly(start)}',
          'select': '*',
          'order': 'business_date.asc',
        });
        return rows
            .map(_exchangeRateFromRow)
            .where((rate) => rate.businessDate.isBefore(end))
            .toList();
      },
    );
  }

  @override
  Future<AppResult<ExchangeRate?>> getRateForDate({
    required String currencyCode,
    required DateTime date,
  }) async {
    return _guard(
      'exchange_rate_read_failed',
      'No se pudo leer tasa de cambio.',
      () async {
        final rows = await _getRows('exchange_rates', {
          'restaurant_id': 'eq.$_restaurantId',
          'currency_code': 'eq.$currencyCode',
          'business_date': 'eq.${_dateOnly(date)}',
          'select': '*',
          'limit': '1',
        });
        return rows.isEmpty ? null : _exchangeRateFromRow(rows.first);
      },
    );
  }

  @override
  Future<AppResult<ExchangeRate>> saveRate(ExchangeRate rate) async {
    return _guard(
      'exchange_rate_save_failed',
      'No se pudo guardar tasa de cambio.',
      () async {
        await _upsert(
          'exchange_rates',
          _exchangeRatePayload(rate),
          conflictColumn: 'restaurant_id,currency_code,business_date',
        );
        return rate;
      },
    );
  }

  @override
  Future<AppResult<List<ExchangeRate>>> fillMonth({
    required String currencyCode,
    required DateTime month,
    required int rateInCents,
  }) async {
    return _guard(
      'exchange_rates_fill_failed',
      'No se pudieron completar tasas de cambio.',
      () async {
        final days = DateTime(month.year, month.month + 1, 0).day;
        final rates = <ExchangeRate>[];
        for (var day = 1; day <= days; day++) {
          final rate = ExchangeRate(
            currencyCode: currencyCode,
            businessDate: DateTime(month.year, month.month, day),
            rateInCents: rateInCents,
          );
          await _upsert(
            'exchange_rates',
            _exchangeRatePayload(rate),
            conflictColumn: 'restaurant_id,currency_code,business_date',
          );
          rates.add(rate);
        }
        return rates;
      },
    );
  }

  Map<String, Object?> _exchangeRatePayload(ExchangeRate rate) {
    return {
      'restaurant_id': _restaurantId,
      'currency_code': rate.currencyCode,
      'business_date': _dateOnly(rate.businessDate),
      'rate': _money(rate.rateInCents),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  RestaurantTable _restaurantTableFromRow(Map<String, Object?> row) {
    final status = _text(row['status'], fallback: 'available');
    return RestaurantTable(
      id: _text(row['id']),
      name: _text(row['name'], fallback: 'Mesa'),
      displayName: _nullableText(row['display_name']),
      status: RestaurantTableStatus.values.firstWhere(
        (value) => value.name == status,
        orElse: () => RestaurantTableStatus.available,
      ),
      isActive: _bool(row['is_active'], fallback: true),
    );
  }
}
