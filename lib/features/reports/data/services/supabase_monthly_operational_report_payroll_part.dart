part of 'supabase_monthly_operational_report_service.dart';

extension _MonthlyOperationalPayrollQueries
    on SupabaseMonthlyOperationalReportService {
  Future<_PayrollTotals> _loadPayroll({
    required DateTime from,
    required DateTime to,
  }) async {
    final actual = await _loadActualPayroll(from: from, to: to);
    final projected = await _loadProjectedPayroll(from: from, to: to);
    final periods = [
      ...actual.periods,
      for (final period in projected.periods)
        if (!_hasActualPayrollFor(period, actual.periods)) period,
    ];
    return _payrollTotals(periods);
  }

  Future<_PayrollTotals> _loadActualPayroll({
    required DateTime from,
    required DateTime to,
  }) async {
    final runs = await _getRows('payroll_runs', {
      'select': 'id,period_start,period_end',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'status': 'neq.voided',
      'period_start': 'lte.${_formatDate(to)}',
      'period_end': 'gte.${_formatDate(from)}',
    });
    final runById = {
      for (final row in runs)
        _requiredText(row, 'id'): (
          from: _dateOnly(_dateTime(row['period_start'])),
          to: _dateOnly(_dateTime(row['period_end'])),
        ),
    };
    if (runById.isEmpty) return const _PayrollTotals();
    final rows = await _getRows('payroll_run_lines', {
      'select': 'payroll_run_id,net_pay,paid_amount,balance_amount',
      'payroll_run_id': 'in.(${runById.keys.join(',')})',
    });
    final values = <String, _PayrollPeriodAccumulator>{};
    for (final row in rows) {
      values
          .putIfAbsent(
            _requiredText(row, 'payroll_run_id'),
            _PayrollPeriodAccumulator.new,
          )
          .add(
            balance: _moneyToCents(row['balance_amount']),
            net: _moneyToCents(row['net_pay']),
            paid: _moneyToCents(row['paid_amount']),
          );
    }
    final periods = values.entries.map((entry) {
      final run = runById[entry.key]!;
      return _PayrollPeriodTotal(
        balance: entry.value.balance,
        from: run.from,
        net: entry.value.net,
        paid: entry.value.paid,
        to: run.to,
      );
    }).toList();
    return _payrollTotals(periods);
  }

  Future<_PayrollTotals> _loadProjectedPayroll({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _getRows('employees', {
      'select': 'base_salary',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'is_active': 'eq.true',
    });
    final fortnightAmount = rows.fold<int>(
      0,
      (total, row) => total + _moneyToCents(row['base_salary']),
    );
    if (fortnightAmount <= 0) return const _PayrollTotals();
    final periods = _fortnightPeriods(from, to).map((period) {
      return _PayrollPeriodTotal(
        balance: fortnightAmount,
        from: period.from,
        net: fortnightAmount,
        paid: 0,
        to: period.to,
      );
    }).toList();
    return _payrollTotals(periods);
  }

  _PayrollTotals _payrollTotals(List<_PayrollPeriodTotal> periods) {
    return _PayrollTotals(
      balance: periods.fold(0, (total, period) => total + period.balance),
      net: periods.fold(0, (total, period) => total + period.net),
      paid: periods.fold(0, (total, period) => total + period.paid),
      periods: periods,
    );
  }

  bool _hasActualPayrollFor(
    _PayrollPeriodTotal projected,
    List<_PayrollPeriodTotal> actual,
  ) {
    return actual.any(
      (period) =>
          !period.to.isBefore(projected.from) &&
          !period.from.isAfter(projected.to),
    );
  }

  List<({DateTime from, DateTime to})> _fortnightPeriods(
    DateTime from,
    DateTime to,
  ) {
    final periods = <({DateTime from, DateTime to})>[];
    var cursor = DateTime(from.year, from.month);
    while (!cursor.isAfter(to)) {
      final first = (from: cursor, to: DateTime(cursor.year, cursor.month, 15));
      final second = (
        from: DateTime(cursor.year, cursor.month, 16),
        to: DateTime(cursor.year, cursor.month + 1, 0),
      );
      for (final period in [first, second]) {
        if (!period.to.isBefore(from) && !period.from.isAfter(to)) {
          periods.add(period);
        }
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return periods;
  }
}
