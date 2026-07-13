part of 'supabase_monthly_operational_report_service.dart';

extension _MonthlyOperationalQueries
    on SupabaseMonthlyOperationalReportService {
  Future<List<_RemoteSale>> _loadSales({
    required DateTime exclusiveTo,
    required DateTime from,
  }) async {
    final rows = await _getRows('sales', {
      'select': 'id,total_amount,sold_at',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'status': 'eq.completed',
      'sale_kind': 'eq.sale',
      'and': _dateRangeFilter('sold_at', from, exclusiveTo),
      'order': 'sold_at.asc',
    });
    return rows.map((row) {
      return _RemoteSale(
        date: _dateOnly(_dateTime(row['sold_at'])),
        id: _requiredText(row, 'id'),
        totalInCents: _moneyToCents(row['total_amount']),
      );
    }).toList();
  }

  Future<List<_RemoteSaleItem>> _loadSaleItems(Iterable<String> saleIds) async {
    final ids = saleIds.toSet();
    if (ids.isEmpty) return const [];
    final rows = await _getRows('sale_items', {
      'select': 'sale_id,quantity,unit_cost',
      'sale_id': 'in.(${ids.join(',')})',
    });
    return rows.map((row) {
      final quantity = _quantity(row['quantity']);
      final unitCost = _moneyToCents(row['unit_cost']);
      return _RemoteSaleItem(
        costInCents: (quantity * unitCost).round(),
        saleId: _requiredText(row, 'sale_id'),
      );
    }).toList();
  }

  Future<Map<String, _ExpenseCategory>> _loadExpenseCategories() async {
    final rows = await _getRows('expense_categories', {
      'select':
          'id,name,parent_id,include_in_gross_profit_coverage,'
          'coverage_expense_type,coverage_estimated_amount,'
          'coverage_frequency,coverage_due_days,coverage_is_active',
      'or':
          '(restaurant_id.eq.${_restaurantService.restaurantId},'
          'restaurant_id.is.null)',
    });
    return {
      for (final row in rows)
        _requiredText(row, 'id'): _ExpenseCategory(
          coverageDueDays: _intList(row['coverage_due_days']),
          coverageEstimatedAmountInCents: _nullableMoneyToCents(
            row['coverage_estimated_amount'],
          ),
          coverageFrequency: _optionalText(row['coverage_frequency']),
          coverageIsActive: row['coverage_is_active'] != false,
          coverageType: _optionalText(row['coverage_expense_type']),
          id: _requiredText(row, 'id'),
          includeInCoverage: row['include_in_gross_profit_coverage'] == true,
          name: _requiredText(row, 'name'),
          parentId: _optionalText(row['parent_id']),
        ),
    };
  }

  Future<List<_RemoteExpense>> _loadExpenses({
    required DateTime exclusiveTo,
    required DateTime from,
  }) async {
    final rows = await _getRows('operating_expenses', {
      'select': 'id,expense_category_id,amount,spent_at',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'expense_kind': 'eq.operational',
      'and': _dateRangeFilter('spent_at', from, exclusiveTo),
      'order': 'spent_at.asc',
    });
    return rows.map((row) {
      return _RemoteExpense(
        amountInCents: _moneyToCents(row['amount']),
        categoryId: _requiredText(row, 'expense_category_id'),
        date: _dateOnly(_dateTime(row['spent_at'])),
      );
    }).toList();
  }

  Future<_PayrollTotals> _loadPayroll({
    required DateTime from,
    required DateTime to,
  }) async {
    final runs = await _getRows('payroll_runs', {
      'select': 'id',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'status': 'neq.voided',
      'period_start': 'lte.${_formatDate(to)}',
      'period_end': 'gte.${_formatDate(from)}',
    });
    final runIds = runs.map((row) => _requiredText(row, 'id')).toSet();
    if (runIds.isEmpty) return const _PayrollTotals();
    final rows = await _getRows('payroll_run_lines', {
      'select': 'net_pay,paid_amount,balance_amount',
      'payroll_run_id': 'in.(${runIds.join(',')})',
    });
    var balance = 0;
    var net = 0;
    var paid = 0;
    for (final row in rows) {
      balance += _moneyToCents(row['balance_amount']);
      net += _moneyToCents(row['net_pay']);
      paid += _moneyToCents(row['paid_amount']);
    }
    return _PayrollTotals(balance: balance, net: net, paid: paid);
  }

  Future<int> _loadAdvances({
    required DateTime exclusiveTo,
    required DateTime from,
  }) async {
    final rows = await _getRows('employee_salary_advances', {
      'select': 'amount',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'and': _dateRangeFilter('delivered_at', from, exclusiveTo),
    });
    var total = 0;
    for (final row in rows) {
      total += _moneyToCents(row['amount']);
    }
    return total;
  }

  Future<int> _loadPendingStaffConsumption({
    required DateTime exclusiveTo,
    required DateTime from,
  }) async {
    final rows = await _getRows('sales', {
      'select': 'total_amount',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'status': 'eq.completed',
      'sale_kind': 'eq.staff_consumption',
      'payroll_run_id': 'is.null',
      'and': _dateRangeFilter('sold_at', from, exclusiveTo),
    });
    var total = 0;
    for (final row in rows) {
      total += _moneyToCents(row['total_amount']);
    }
    return total;
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> queryParameters,
  ) async {
    final response = await _client.get(
      _config.restUri(table, queryParameters),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _remoteSessionService.expire();
      }
      throw StateError(
        'Supabase rechazo consulta de $table '
        '(${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Map<String, String> _headers() {
    return {
      'apikey': _config.publishableKey,
      'Authorization': 'Bearer ${_remoteSessionService.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  String _dateRangeFilter(String column, DateTime from, DateTime to) {
    return '($column.gte.${from.toUtc().toIso8601String()},'
        '$column.lt.${to.toUtc().toIso8601String()})';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _dateTime(Object? value) {
    final text = _optionalText(value);
    if (text == null) throw StateError('Missing remote date.');
    return DateTime.parse(text).toLocal();
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  int _moneyToCents(Object? value) {
    if (value == null) return 0;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value.toString()) ?? 0) * 100).round();
  }

  int? _nullableMoneyToCents(Object? value) {
    if (value == null) return null;
    return _moneyToCents(value);
  }

  List<int> _intList(Object? value) {
    if (value is List) {
      return value.whereType<num>().map((day) => day.round()).toList()
        ..sort();
    }
    return const [];
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  num _quantity(Object? value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  String _requiredText(Map<String, Object?> row, String key) {
    final value = _optionalText(row[key]);
    if (value == null) throw StateError('Missing required field $key.');
    return value;
  }
}
