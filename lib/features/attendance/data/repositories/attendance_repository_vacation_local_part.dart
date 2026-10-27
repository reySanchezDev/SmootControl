part of 'attendance_repository.dart';

Future<AppResult<VacationRequest>> _requestVacation(
  AttendanceRepository repository, {
  required Employee employee,
  required DateTime startDate,
  required DateTime endDate,
  String? note,
}) {
  return repository._guard(
    'vacation_request_save_failed',
    'No se pudo guardar solicitud de vacaciones.',
    () async {
      final now = DateTime.now();
      final request = VacationRequest(
        id: repository._uuid.v4(),
        employeeId: employee.id,
        employeeName: employee.fullName,
        startDate: _onlyDate(startDate),
        endDate: _onlyDate(endDate),
        requestedDays: _inclusiveDays(startDate, endDate),
        requestType: 'planned',
        status: 'pending',
        source: 'time_clock',
        note: note,
        createdAt: now,
      );
      final saved = await repository._localDataSource.saveVacationRequest(
        request,
      );
      final syncResult = await _enqueueVacationAndTrySync(repository, saved);
      if (syncResult case AppFailureResult(:final error)) {
        throw StateError(error.message);
      }
      return saved;
    },
  );
}

Future<AppResult<void>> _enqueueVacationAndTrySync(
  AttendanceRepository repository,
  VacationRequest request,
) async {
  final queued = await repository._syncQueueRepository.enqueue(
    entityType: 'employee_vacation_requests',
    entityId: request.id,
    operation: SyncOperation.create,
    syncImmediately: false,
    payload: {
      'id': request.id,
      'employeeId': request.employeeId,
      'startDate': repository._dateOnly(request.startDate),
      'endDate': repository._dateOnly(request.endDate),
      'requestedDays': request.requestedDays,
      'requestType': request.requestType,
      'status': request.status,
      'source': request.source,
      'note': request.note,
      'createdAt': request.createdAt.toIso8601String(),
    },
  );
  return switch (queued) {
    AppFailureResult() => const AppSuccess<void>(null),
    AppSuccess(:final value) => repository._trySyncNow(value),
  };
}

DateTime _onlyDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

double _inclusiveDays(DateTime from, DateTime to) {
  return _onlyDate(to).difference(_onlyDate(from)).inDays + 1;
}
