part of 'supabase_staff_admin_repository.dart';

abstract class _SupabaseStaffAdminRepositoryBase {
  /// Creates the repository.
  const _SupabaseStaffAdminRepositoryBase({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
  }) : _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;

  String get _restaurantId => _restaurantService.restaurantId;

  Future<AppResult<T>> _guard<T>(
    String code,
    String message,
    Future<T> Function() run,
  ) async {
    try {
      return AppSuccess(await run());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: code,
          message: _withCause(message, error),
          cause: error,
        ),
      );
    }
  }

  String _withCause(String message, Object error) {
    final detail = _remoteErrorMessage(error);
    if (detail == null || detail.isEmpty) return message;
    return '$message\n\nDetalle: $detail';
  }

  String? _remoteErrorMessage(Object error) {
    final text = error.toString();
    final jsonStart = text.indexOf('{');
    if (jsonStart < 0) return text.replaceFirst('Bad state: ', '');
    try {
      final decoded = jsonDecode(text.substring(jsonStart));
      if (decoded is Map<String, Object?>) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) return message;
      }
    } on Object {
      return text.replaceFirst('Bad state: ', '');
    }
    return text.replaceFirst('Bad state: ', '');
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> query,
  ) async {
    final response = await _client.get(
      _config.restUri(table, query),
      headers: await _headers(),
    );
    _ensureSuccess(response, table);
    final body = jsonDecode(response.body);
    if (body is! List) return const [];
    return body.whereType<Map<Object?, Object?>>().map(_map).toList();
  }

  Future<void> _upsert(
    String table,
    Map<String, Object?> payload, {
    String conflictColumn = 'id',
  }) async {
    final response = await _client.post(
      _config.restUri(table, {'on_conflict': conflictColumn}),
      headers: await _headers(
        prefer: 'resolution=merge-duplicates,return=minimal',
      ),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, table);
  }

  Future<void> _rpc(String functionName, Map<String, Object?> payload) async {
    final response = await _client.post(
      _config.rpcUri(functionName),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, functionName);
  }

  Future<Map<String, Object?>> _rpcRow(
    String functionName,
    Map<String, Object?> payload,
  ) async {
    final response = await _client.post(
      _config.rpcUri(functionName),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, functionName);
    final body = jsonDecode(response.body);
    if (body is Map<Object?, Object?>) return _map(body);
    throw StateError('Respuesta invalida de $functionName');
  }

  Future<List<Map<String, Object?>>> _rpcRows(
    String functionName,
    Map<String, Object?> payload,
  ) async {
    final response = await _client.post(
      _config.rpcUri(functionName),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, functionName);
    final body = jsonDecode(response.body);
    if (body is! List) return const [];
    return body.whereType<Map<Object?, Object?>>().map(_map).toList();
  }

  Future<Map<String, String>> _headers({String? prefer}) async {
    final token = _remoteSessionService.accessToken;
    if (!_config.isConfigured || token == null) {
      throw StateError('Supabase no esta configurado para admin remoto.');
    }
    return {
      'apikey': _config.publishableKey,
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      ...?(prefer == null ? null : {'prefer': prefer}),
    };
  }

  void _ensureSuccess(http.Response response, String context) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      _remoteSessionService.expire();
    }
    throw StateError('Supabase rechazo $context: ${response.body}');
  }

  Employee _employeeFromRow(Map<String, Object?> row) {
    return Employee(
      id: _text(row['id']),
      code: _optionalText(row['code']) ?? _optionalText(row['employee_number']),
      fullName: _text(row['full_name']),
      positionName:
          _optionalText(row['position_id']) ??
          _optionalText(row['position_name']),
      baseSalaryInCents: _moneyToCents(row['base_salary']),
      isActive: _bool(row['is_active'], fallback: true),
      photoUrl: _optionalText(row['photo_url']),
      showInTimeClock: _bool(row['show_in_time_clock'], fallback: true),
    );
  }

  EmployeePosition _positionFromRow(Map<String, Object?> row) {
    return EmployeePosition(
      id: _text(row['id']),
      name: _text(row['name']),
      displayOrder: _int(row['display_order']),
      isActive: _bool(row['is_active'], fallback: true),
    );
  }

  BusinessRule _ruleFromRow(Map<String, Object?> row) {
    return BusinessRule(
      key: _text(row['key']),
      boolValue: row['bool_value'] as bool?,
      textValue: _optionalText(row['text_value']),
    );
  }

  SalaryAdvance _advanceFromRow(Map<String, Object?> row) {
    return SalaryAdvance(
      id: _text(row['id']),
      employeeId: _text(row['employee_id']),
      cashRegisterSessionId: _optionalText(row['cash_register_session_id']),
      amountInCents: _moneyToCents(row['amount']),
      balanceInCents: _moneyToCents(row['balance_amount']),
      affectsCash: _bool(row['affects_cash']),
      note: _optionalText(row['note']),
      createdBy: _text(row['created_by_user_id']),
      status: _text(row['status'], defaultValue: 'pending'),
      createdAt: DateTime.tryParse(_text(row['created_at'])) ?? DateTime.now(),
      deliveredAt:
          DateTime.tryParse(_text(row['delivered_at'])) ??
          DateTime.tryParse(_text(row['created_at'])) ??
          DateTime.now(),
    );
  }

  PayrollPendingLine _pendingPayrollLineFromRow(Map<String, Object?> row) {
    final start =
        DateTime.tryParse(_text(row['period_start'])) ?? DateTime.now();
    final end = DateTime.tryParse(_text(row['period_end'])) ?? start;
    return PayrollPendingLine(
      payrollRunId: _text(row['payroll_run_id']),
      employeeId: _text(row['employee_id']),
      employeeName: _text(row['employee_name'], defaultValue: 'Empleado'),
      periodStart: start,
      periodEnd: end,
      periodLabel: _text(row['period_label'], defaultValue: 'Planilla'),
      baseSalaryInCents: _moneyToCents(row['base_salary']),
      consumptionInCents: _moneyToCents(row['staff_consumption_amount']),
      overtimeInCents: _moneyToCents(row['overtime_amount']),
      salaryAdvanceDeductionInCents: _moneyToCents(
        row['salary_advance_deduction'],
      ),
      netPayInCents: _moneyToCents(row['net_pay']),
      paidInCents: _moneyToCents(row['paid_amount']),
      balanceInCents: _moneyToCents(row['balance_amount']),
    );
  }

  EmployeeOvertimeEntry _overtimeFromRow(Map<String, Object?> row) {
    return EmployeeOvertimeEntry(
      id: _text(row['id']),
      employeeId: _text(row['employee_id']),
      employeeName: _text(row['employee_name'], defaultValue: 'Empleado'),
      workedDate:
          DateTime.tryParse(_text(row['worked_date'])) ?? DateTime.now(),
      hours: double.tryParse(_text(row['hours'])) ?? 0,
      hourRateInCents: _moneyToCents(row['hour_rate']),
      totalInCents: _moneyToCents(row['total_amount']),
      note: _optionalText(row['note']),
      status: _text(row['status'], defaultValue: 'pending'),
      payrollRunId: _optionalText(row['payroll_run_id']),
      payrollRunLineId: _optionalText(row['payroll_run_line_id']),
      createdAt: DateTime.tryParse(_text(row['created_at'])) ?? DateTime.now(),
    );
  }

  Map<String, Object?> _map(Map<Object?, Object?> row) {
    return row.map((key, value) => MapEntry(key.toString(), value));
  }

  String _text(Object? value, {String defaultValue = ''}) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return defaultValue;
    return text;
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text?.isEmpty ?? true ? null : text;
  }

  bool _bool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return fallback;
  }

  int _moneyToCents(Object? value) {
    if (value is int) return value * 100;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value?.toString() ?? '') ?? 0) * 100).round();
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  num _money(int cents) => cents / 100;

  String _dateOnly(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
