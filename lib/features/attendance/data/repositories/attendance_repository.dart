import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/attendance/data/datasources/local_attendance_datasource.dart';
import 'package:smoo_control/features/attendance/domain/entities/attendance_entry.dart';
import 'package:smoo_control/features/attendance/domain/entities/overtime_candidate.dart';
import 'package:smoo_control/features/attendance/domain/repositories/i_attendance_repository.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';
import 'package:smoo_control/features/sync/domain/services/sync_error_message.dart';
import 'package:uuid/uuid.dart';

part 'attendance_repository_remote_part.dart';

/// Attendance repository for local time-clock and remote admin operations.
final class AttendanceRepository
    with _AttendanceRemoteMixin
    implements IAttendanceRepository {
  /// Creates the attendance repository.
  const AttendanceRepository({
    required LocalAttendanceDataSource localDataSource,
    required ISyncQueueRepository syncQueueRepository,
    required ISyncRemoteSender remoteSender,
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
    Uuid uuid = const Uuid(),
  }) : _localDataSource = localDataSource,
       _syncQueueRepository = syncQueueRepository,
       _remoteSender = remoteSender,
       _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client,
       _uuid = uuid;

  final LocalAttendanceDataSource _localDataSource;
  final ISyncQueueRepository _syncQueueRepository;
  final ISyncRemoteSender _remoteSender;
  @override
  final SupabaseAppConfig _config;
  @override
  final CurrentRestaurantService _restaurantService;
  @override
  final CurrentRemoteSessionService _remoteSessionService;
  @override
  final http.Client _client;
  final Uuid _uuid;

  @override
  Future<AppResult<List<Employee>>> getClockEmployees() async {
    return _guard(
      'attendance_employees_failed',
      'No se pudo leer personal.',
      _localDataSource.getClockEmployees,
    );
  }

  @override
  Future<AppResult<AttendanceEntry?>> getOpenEntry(String employeeId) async {
    return _guard('attendance_open_failed', 'No se pudo leer la jornada.', () {
      return _localDataSource.getOpenEntry(employeeId);
    });
  }

  @override
  Future<AppResult<AttendanceEntry>> clockIn(Employee employee) async {
    return _saveLocalMark(employee: employee, openEntry: null);
  }

  @override
  Future<AppResult<AttendanceEntry>> clockOut(AttendanceEntry entry) async {
    return _saveLocalMark(employee: null, openEntry: entry);
  }

  Future<AppResult<AttendanceEntry>> _saveLocalMark({
    required Employee? employee,
    required AttendanceEntry? openEntry,
  }) async {
    return _guard(
      'attendance_save_failed',
      'No se pudo guardar marcada.',
      () async {
        final now = DateTime.now();
        final entry = openEntry == null
            ? AttendanceEntry(
                id: _uuid.v4(),
                employeeId: employee!.id,
                employeeName: employee.fullName,
                workDate: DateTime(now.year, now.month, now.day),
                clockInAt: now,
                status: 'open',
                source: 'time_clock',
                verificationMethod: 'photo_tap',
                createdAt: now,
              )
            : AttendanceEntry(
                id: openEntry.id,
                employeeId: openEntry.employeeId,
                employeeName: openEntry.employeeName,
                workDate: openEntry.workDate,
                clockInAt: openEntry.clockInAt,
                clockOutAt: now,
                status: 'closed',
                source: openEntry.source,
                verificationMethod: openEntry.verificationMethod,
                note: openEntry.note,
                createdAt: openEntry.createdAt,
              );
        final saved = await _localDataSource.saveEntry(entry);
        await _enqueueAndTrySync(saved);
        return saved;
      },
    );
  }

  Future<void> _enqueueAndTrySync(AttendanceEntry entry) async {
    final queued = await _syncQueueRepository.enqueue(
      entityType: 'employee_attendance_entries',
      entityId: entry.id,
      operation: SyncOperation.create,
      syncImmediately: false,
      payload: {
        'id': entry.id,
        'employeeId': entry.employeeId,
        'workDate': _dateOnly(entry.workDate),
        'clockInAt': entry.clockInAt?.toIso8601String(),
        'clockOutAt': entry.clockOutAt?.toIso8601String(),
        'status': entry.status,
        'source': entry.source,
        'verificationMethod': entry.verificationMethod,
        'note': entry.note,
        'createdAt': entry.createdAt.toIso8601String(),
      },
    );

    switch (queued) {
      case AppFailureResult():
        return;
      case AppSuccess(:final value):
        await _trySyncNow(value);
    }
  }

  Future<void> _trySyncNow(SyncQueueItem item) async {
    try {
      await _remoteSender.push(item).timeout(const Duration(seconds: 12));
      await _syncQueueRepository.markSynced(item.id);
    } on Object catch (error) {
      await _syncQueueRepository.markError(
        itemId: item.id,
        error: syncErrorMessage(error),
      );
    }
  }

  @override
  String _dateOnly(DateTime date) {
    return date.toIso8601String().substring(0, 10);
  }

  @override
  Future<AppResult<T>> _guard<T>(
    String code,
    String message,
    Future<T> Function() run,
  ) async {
    try {
      return AppSuccess(await run());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(code: code, message: message, cause: error),
      );
    }
  }
}
