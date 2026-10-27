import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/attendance/domain/entities/attendance_entry.dart';
import 'package:smoo_control/features/attendance/domain/entities/vacation_request.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';

/// Local datasource for attendance marks created by the time-clock APK.
final class LocalAttendanceDataSource {
  /// Creates the datasource.
  const LocalAttendanceDataSource(this._database);

  final AppDatabase _database;

  /// Returns device credentials for device-authenticated attendance RPCs.
  Future<AttendanceDeviceCredentials> deviceCredentials() async {
    final state = await (_database.select(
      _database.localDeviceState,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
    final deviceId = _nonEmpty(state?.syncDeviceId ?? state?.deviceId);
    final secret = _nonEmpty(state?.syncDeviceSecret);
    if (deviceId == null || secret == null) {
      throw StateError(
        'Este marcador no tiene credenciales de sincronizacion.',
      );
    }
    return AttendanceDeviceCredentials(deviceId: deviceId, secret: secret);
  }

  /// Returns active employees visible in the time-clock.
  Future<List<Employee>> getClockEmployees() async {
    final rows =
        await (_database.select(_database.localEmployees)
              ..where(
                (row) =>
                    row.isActive.equals(true) &
                    row.showInTimeClock.equals(true),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.fullName)]))
            .get();
    return rows.map(_employeeFromRow).toList();
  }

  /// Returns today's active attendance entry for an employee.
  Future<AttendanceEntry?> getOpenEntry(String employeeId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final row =
        await (_database.select(_database.localAttendanceEntries)
              ..where(
                (entry) =>
                    entry.employeeId.equals(employeeId) &
                    entry.workDate.equals(today) &
                    (entry.status.equals('open') |
                        entry.status.equals('closed')),
              )
              ..orderBy([(entry) => OrderingTerm.desc(entry.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    final employee = await _employeeById(row.employeeId);
    return _entryFromRow(row, employeeName: employee?.fullName ?? 'Empleado');
  }

  /// Saves one local attendance entry.
  Future<AttendanceEntry> saveEntry(AttendanceEntry entry) async {
    await _saveEntry(entry, syncStatus: 'pending');
    return entry;
  }

  /// Saves one local vacation request created by the marker.
  Future<VacationRequest> saveVacationRequest(VacationRequest request) async {
    final now = DateTime.now();
    await _database
        .into(_database.localVacationRequests)
        .insert(
          LocalVacationRequestsCompanion(
            id: Value(request.id),
            employeeId: Value(request.employeeId),
            startDate: Value(request.startDate),
            endDate: Value(request.endDate),
            requestedDays: Value(request.requestedDays),
            requestType: Value(request.requestType),
            status: Value(request.status),
            source: Value(request.source),
            note: Value(request.note),
            syncStatus: const Value('pending'),
            syncError: const Value(null),
            createdAt: Value(request.createdAt),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
    return request;
  }

  /// Replaces local day state with the remote source of truth.
  Future<void> applyRemoteEntriesForDate({
    required DateTime workDate,
    required List<AttendanceEntry> entries,
    String? employeeId,
  }) async {
    final date = DateTime(workDate.year, workDate.month, workDate.day);
    await _database.transaction(() async {
      final remoteIds = entries.map((entry) => entry.id).toSet();
      final employees = employeeId == null
          ? entries.map((entry) => entry.employeeId).toSet()
          : {employeeId};

      for (final currentEmployeeId in employees) {
        await (_database.delete(_database.localAttendanceEntries)..where((
              entry,
            ) {
              final sameEmployeeAndDate =
                  entry.employeeId.equals(currentEmployeeId) &
                  entry.workDate.equals(date);
              if (remoteIds.isEmpty) {
                return sameEmployeeAndDate & entry.syncStatus.equals('synced');
              }
              final differentRemoteEntry = entry.id.isNotIn(remoteIds);
              return sameEmployeeAndDate & differentRemoteEntry;
            }))
            .go();
      }

      for (final entry in entries) {
        await _saveEntry(entry, syncStatus: 'synced');
      }
    });
  }

  Future<Employee?> _employeeById(String id) async {
    final row = await (_database.select(
      _database.localEmployees,
    )..where((employee) => employee.id.equals(id))).getSingleOrNull();
    return row == null ? null : _employeeFromRow(row);
  }

  AttendanceEntry _entryFromRow(
    LocalAttendanceEntry row, {
    required String employeeName,
  }) {
    return AttendanceEntry(
      id: row.id,
      employeeId: row.employeeId,
      employeeName: employeeName,
      workDate: row.workDate,
      clockInAt: row.clockInAt,
      clockOutAt: row.clockOutAt,
      status: row.status,
      source: row.source,
      verificationMethod: row.verificationMethod,
      note: row.note,
      createdAt: row.createdAt,
    );
  }

  Employee _employeeFromRow(LocalEmployee row) {
    return Employee(
      id: row.id,
      code: row.code,
      fullName: row.fullName,
      positionName: row.positionName,
      baseSalaryInCents: row.baseSalaryInCents,
      isActive: row.isActive,
      photoUrl: row.photoUrl,
      showInTimeClock: row.showInTimeClock,
    );
  }

  Future<void> _saveEntry(
    AttendanceEntry entry, {
    required String syncStatus,
  }) async {
    final now = DateTime.now();
    await _database
        .into(_database.localAttendanceEntries)
        .insert(
          LocalAttendanceEntriesCompanion(
            id: Value(entry.id),
            employeeId: Value(entry.employeeId),
            workDate: Value(entry.workDate),
            clockInAt: Value(entry.clockInAt),
            clockOutAt: Value(entry.clockOutAt),
            status: Value(entry.status),
            source: Value(entry.source),
            verificationMethod: Value(entry.verificationMethod),
            note: Value(entry.note),
            syncStatus: Value(syncStatus),
            syncError: const Value(null),
            createdAt: Value(entry.createdAt),
            updatedAt: Value(now),
            syncedAt: syncStatus == 'synced' ? Value(now) : const Value(null),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  String? _nonEmpty(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

/// Device credentials used by the standalone marker.
final class AttendanceDeviceCredentials {
  /// Creates device credentials.
  const AttendanceDeviceCredentials({
    required this.deviceId,
    required this.secret,
  });

  /// Remote POS device id.
  final String deviceId;

  /// Device secret used by Supabase RPCs.
  final String secret;
}
