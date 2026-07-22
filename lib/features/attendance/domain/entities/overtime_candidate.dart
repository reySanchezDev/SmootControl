import 'package:equatable/equatable.dart';

/// Overtime calculated from attendance and waiting for admin approval.
final class OvertimeCandidate extends Equatable {
  /// Creates an overtime candidate.
  const OvertimeCandidate({
    required this.id,
    required this.attendanceEntryId,
    required this.employeeId,
    required this.employeeName,
    required this.workedDate,
    required this.hours,
    required this.hourRateInCents,
    required this.totalInCents,
    required this.status,
    this.note,
  });

  /// Candidate identifier.
  final String id;

  /// Attendance entry that produced this candidate.
  final String attendanceEntryId;

  /// Employee identifier.
  final String employeeId;

  /// Employee display name.
  final String employeeName;

  /// Day when overtime was worked.
  final DateTime workedDate;

  /// Overtime hours.
  final double hours;

  /// Captured hour rate.
  final int hourRateInCents;

  /// Total amount.
  final int totalInCents;

  /// pending, approved or rejected.
  final String status;

  /// Optional note.
  final String? note;

  /// Whether the candidate can be approved or rejected.
  bool get isPending => status == 'pending';

  @override
  List<Object?> get props => [
    id,
    attendanceEntryId,
    employeeId,
    employeeName,
    workedDate,
    hours,
    hourRateInCents,
    totalInCents,
    status,
    note,
  ];
}
