import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/attendance/domain/entities/attendance_entry.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';

/// Local datasource for attendance marks created by the time-clock APK.
final class LocalAttendanceDataSource {
  /// Creates the datasource.
  const LocalAttendanceDataSource(this._database);

  final AppDatabase _database;

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
            syncStatus: const Value('pending'),
            syncError: const Value(null),
            createdAt: Value(entry.createdAt),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
    return entry;
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
}
