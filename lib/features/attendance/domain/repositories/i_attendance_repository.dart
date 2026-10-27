import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/attendance/domain/entities/attendance_entry.dart';
import 'package:smoo_control/features/attendance/domain/entities/overtime_candidate.dart';
import 'package:smoo_control/features/attendance/domain/entities/vacation_request.dart';
import 'package:smoo_control/features/attendance/domain/entities/vacation_summary.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';

/// Contract for attendance and overtime approval flows.
abstract interface class IAttendanceRepository {
  /// Returns active employees visible in the time-clock.
  Future<AppResult<List<Employee>>> getClockEmployees();

  /// Returns the local open entry for an employee, if any.
  Future<AppResult<AttendanceEntry?>> getOpenEntry(String employeeId);

  /// Refreshes today's remote attendance entries into the local marker cache.
  Future<AppResult<void>> refreshTodayEntries({String? employeeId});

  /// Registers an entry mark locally and queues sync.
  Future<AppResult<AttendanceEntry>> clockIn(Employee employee);

  /// Registers an exit mark locally and queues sync.
  Future<AppResult<AttendanceEntry>> clockOut(AttendanceEntry entry);

  /// Reads attendance entries from the remote admin source.
  Future<AppResult<List<AttendanceEntry>>> getRemoteEntries({
    required DateTime from,
    required DateTime to,
    String? employeeId,
    String? status,
  });

  /// Saves a remote admin attendance entry.
  Future<AppResult<void>> saveRemoteEntry(AttendanceEntry entry);

  /// Voids a remote attendance entry.
  Future<AppResult<void>> voidRemoteEntry(String entryId);

  /// Reads overtime candidates awaiting admin decision.
  Future<AppResult<List<OvertimeCandidate>>> getOvertimeCandidates({
    required DateTime from,
    required DateTime to,
    String? status,
  });

  /// Approves one overtime candidate and creates the payroll overtime entry.
  Future<AppResult<void>> approveOvertimeCandidate(String candidateId);

  /// Rejects one overtime candidate.
  Future<AppResult<void>> rejectOvertimeCandidate(String candidateId);

  /// Creates a marker vacation request locally and queues sync.
  Future<AppResult<VacationRequest>> requestVacation({
    required Employee employee,
    required DateTime startDate,
    required DateTime endDate,
    String? note,
  });

  /// Reads vacation requests from the remote admin source.
  Future<AppResult<List<VacationRequest>>> getVacationRequests({
    required DateTime from,
    required DateTime to,
    String? employeeId,
    String? status,
  });

  /// Saves a remote admin vacation request.
  Future<AppResult<void>> saveVacationRequest(VacationRequest request);

  /// Changes a vacation request status.
  Future<AppResult<void>> setVacationStatus(String requestId, String status);

  /// Deletes a vacation request permanently from Supabase.
  Future<AppResult<void>> deleteVacationRequest(String requestId);

  /// Reads consolidated vacation balances.
  Future<AppResult<List<VacationSummary>>> getVacationSummary({
    required DateTime asOf,
    String? employeeId,
  });
}
