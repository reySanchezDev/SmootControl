part of 'attendance_repository.dart';

mixin _AttendanceRemoteMixin on Object {
  SupabaseAppConfig get _config;
  CurrentRemoteSessionService get _remoteSessionService;
  CurrentRestaurantService get _restaurantService;
  http.Client get _client;
  String _dateOnly(DateTime date);
  Future<AppResult<T>> _guard<T>(
    String code,
    String message,
    Future<T> Function() run,
  );

  Future<AppResult<List<AttendanceEntry>>> getRemoteEntries({
    required DateTime from,
    required DateTime to,
    String? employeeId,
    String? status,
  }) {
    return _guard(
      'attendance_remote_read_failed',
      'No se pudieron leer las marcadas.',
      () async {
        final rows = await _rpcRows('app_get_employee_attendance_entries', {
          'p_from': _dateOnly(from),
          'p_to': _dateOnly(to),
          'p_employee_id': employeeId,
          'p_status': status,
        });
        return rows.map(_attendanceFromRow).toList();
      },
    );
  }

  Future<AppResult<void>> saveRemoteEntry(AttendanceEntry entry) {
    return _guard(
      'attendance_remote_save_failed',
      'No se pudo guardar la marcada.',
      () async {
        await _rpc('app_save_employee_attendance_entry', {
          'p_payload': _remotePayload(entry),
        });
      },
    );
  }

  Future<AppResult<void>> voidRemoteEntry(String entryId) {
    return _guard(
      'attendance_remote_void_failed',
      'No se pudo eliminar la marcada.',
      () => _rpc('app_void_employee_attendance_entry', {'p_entry_id': entryId}),
    );
  }

  Future<AppResult<List<OvertimeCandidate>>> getOvertimeCandidates({
    required DateTime from,
    required DateTime to,
    String? status,
  }) {
    return _guard(
      'overtime_candidates_read_failed',
      'No se pudieron leer horas extra por autorizar.',
      () async {
        final rows = await _rpcRows('app_get_employee_overtime_candidates', {
          'p_from': _dateOnly(from),
          'p_to': _dateOnly(to),
          'p_status': status,
        });
        return rows.map(_candidateFromRow).toList();
      },
    );
  }

  Future<AppResult<void>> approveOvertimeCandidate(String candidateId) {
    return _guard(
      'overtime_candidate_approve_failed',
      'No se pudo autorizar la hora extra.',
      () => _rpc('app_approve_employee_overtime_candidate', {
        'p_candidate_id': candidateId,
      }),
    );
  }

  Future<AppResult<void>> rejectOvertimeCandidate(String candidateId) {
    return _guard(
      'overtime_candidate_reject_failed',
      'No se pudo rechazar la hora extra.',
      () => _rpc('app_reject_employee_overtime_candidate', {
        'p_candidate_id': candidateId,
      }),
    );
  }

  Map<String, Object?> _remotePayload(AttendanceEntry entry) {
    return {
      'id': entry.id,
      'employee_id': entry.employeeId,
      'work_date': _dateOnly(entry.workDate),
      'clock_in_at': entry.clockInAt?.toIso8601String(),
      'clock_out_at': entry.clockOutAt?.toIso8601String(),
      'status': entry.status,
      'source': entry.source,
      'verification_method': entry.verificationMethod,
      'note': entry.note,
    };
  }

  Future<List<Map<String, Object?>>> _rpcRows(
    String functionName,
    Map<String, Object?> body,
  ) async {
    final decoded = await _rpc(functionName, body);
    if (decoded is! List) return const [];
    return decoded.map(_mapRow).toList();
  }

  Future<Object?> _rpc(String functionName, Map<String, Object?> body) async {
    final response = await _client.post(
      _config.rpcUri(functionName),
      headers: _headers(),
      body: jsonEncode({'p_restaurant_id': _restaurantId, ...body}),
    );
    _ensureSuccess(response, functionName);
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }

  Map<String, String> _headers() {
    final token = _remoteSessionService.accessToken;
    if (!_config.isConfigured || token == null) {
      throw StateError('Supabase no esta configurado para admin remoto.');
    }
    return {
      'apikey': _config.publishableKey,
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'accept': 'application/json',
    };
  }

  void _ensureSuccess(http.Response response, String context) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      _remoteSessionService.expire();
    }
    throw StateError('Supabase rechazo $context: ${response.body}');
  }

  AttendanceEntry _attendanceFromRow(Map<String, Object?> row) {
    return AttendanceEntry(
      id: _text(row['id']),
      employeeId: _text(row['employee_id']),
      employeeName: _text(row['employee_name'], fallback: 'Empleado'),
      workDate: _date(row['work_date']),
      clockInAt: _nullableDate(row['clock_in_at']),
      clockOutAt: _nullableDate(row['clock_out_at']),
      status: _text(row['status'], fallback: 'open'),
      source: _text(row['source'], fallback: 'time_clock'),
      verificationMethod: _text(row['verification_method']),
      note: _optionalText(row['note']),
      deviceName: _optionalText(row['device_name']),
      createdAt: _date(row['created_at']),
    );
  }

  OvertimeCandidate _candidateFromRow(Map<String, Object?> row) {
    return OvertimeCandidate(
      id: _text(row['id']),
      attendanceEntryId: _text(row['attendance_entry_id']),
      employeeId: _text(row['employee_id']),
      employeeName: _text(row['employee_name'], fallback: 'Empleado'),
      workedDate: _date(row['worked_date']),
      hours: double.tryParse(_text(row['hours'])) ?? 0,
      hourRateInCents: _moneyToCents(row['hour_rate']),
      totalInCents: _moneyToCents(row['total_amount']),
      status: _text(row['status'], fallback: 'pending'),
      note: _optionalText(row['note']),
    );
  }

  Map<String, Object?> _mapRow(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  String get _restaurantId => _restaurantService.restaurantId;

  DateTime _date(Object? value) {
    return DateTime.tryParse(_text(value)) ?? DateTime.now();
  }

  DateTime? _nullableDate(Object? value) {
    final text = _optionalText(value);
    return text == null ? null : DateTime.tryParse(text);
  }

  String _text(Object? value, {String fallback = ''}) {
    return value?.toString() ?? fallback;
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int _moneyToCents(Object? value) {
    final parsed = value is num ? value : num.tryParse(value?.toString() ?? '');
    return ((parsed ?? 0) * 100).round();
  }
}
