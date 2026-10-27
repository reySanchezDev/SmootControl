part of 'attendance_repository.dart';

mixin _AttendanceVacationRemoteMixin on _AttendanceRemoteMixin {
  Future<AppResult<List<VacationRequest>>> getVacationRequests({
    required DateTime from,
    required DateTime to,
    String? employeeId,
    String? status,
  }) {
    return _guard(
      'vacation_requests_read_failed',
      'No se pudieron leer las vacaciones.',
      () async {
        final rows = await _rpcRows('app_get_employee_vacation_requests', {
          'p_from': _dateOnly(from),
          'p_to': _dateOnly(to),
          'p_employee_id': employeeId,
          'p_status': status,
        });
        return rows.map(_vacationFromRow).toList();
      },
    );
  }

  Future<AppResult<void>> saveVacationRequest(VacationRequest request) {
    return _guard(
      'vacation_request_remote_save_failed',
      'No se pudo guardar vacaciones.',
      () => _rpc('app_save_employee_vacation_request', {
        'p_payload': _vacationPayload(request),
      }),
    );
  }

  Future<AppResult<void>> setVacationStatus(String requestId, String status) {
    return _guard(
      'vacation_request_status_failed',
      'No se pudo cambiar el estado de vacaciones.',
      () => _rpc('app_set_employee_vacation_status', {
        'p_request_id': requestId,
        'p_status': status,
      }),
    );
  }

  Future<AppResult<void>> deleteVacationRequest(String requestId) {
    return _guard(
      'vacation_request_delete_failed',
      'No se pudo eliminar vacaciones.',
      () => _rpc('app_delete_employee_vacation_request', {
        'p_request_id': requestId,
      }),
    );
  }

  Future<AppResult<List<VacationSummary>>> getVacationSummary({
    required DateTime asOf,
    String? employeeId,
  }) {
    return _guard(
      'vacation_summary_read_failed',
      'No se pudo leer reporte de vacaciones.',
      () async {
        final rows = await _rpcRows('app_get_employee_vacation_summary', {
          'p_as_of': _dateOnly(asOf),
          'p_employee_id': employeeId,
        });
        return rows.map(_vacationSummaryFromRow).toList();
      },
    );
  }

  Map<String, Object?> _vacationPayload(VacationRequest request) {
    return {
      'id': request.id,
      'employee_id': request.employeeId,
      'start_date': _dateOnly(request.startDate),
      'end_date': _dateOnly(request.endDate),
      'requested_days': request.requestedDays,
      'request_type': request.requestType,
      'status': request.status,
      'note': request.note,
    };
  }

  VacationRequest _vacationFromRow(Map<String, Object?> row) {
    return VacationRequest(
      id: _text(row['id']),
      employeeId: _text(row['employee_id']),
      employeeName: _text(row['employee_name'], fallback: 'Empleado'),
      startDate: _date(row['start_date']),
      endDate: _date(row['end_date']),
      requestedDays: double.tryParse(_text(row['requested_days'])) ?? 0,
      requestType: _text(row['request_type'], fallback: 'planned'),
      status: _text(row['status'], fallback: 'pending'),
      source: _text(row['source'], fallback: 'admin'),
      note: _optionalText(row['note']),
      deviceName: _optionalText(row['device_name']),
      approvedAt: _nullableDate(row['approved_at']),
      createdAt: _date(row['created_at']),
    );
  }

  VacationSummary _vacationSummaryFromRow(Map<String, Object?> row) {
    return VacationSummary(
      employeeId: _text(row['employee_id']),
      employeeName: _text(row['employee_name'], fallback: 'Empleado'),
      startDate: _date(row['start_date']),
      accumulatedDays: double.tryParse(_text(row['accumulated_days'])) ?? 0,
      takenDays: double.tryParse(_text(row['taken_days'])) ?? 0,
      scheduledDays: double.tryParse(_text(row['scheduled_days'])) ?? 0,
      scheduledFrom: _nullableDate(row['scheduled_from']),
      scheduledTo: _nullableDate(row['scheduled_to']),
      currentBalance: double.tryParse(_text(row['current_balance'])) ?? 0,
      projectedBalance: double.tryParse(_text(row['projected_balance'])) ?? 0,
    );
  }
}
