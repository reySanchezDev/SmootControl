import 'package:equatable/equatable.dart';

/// Manual overtime entry assigned to one employee.
final class EmployeeOvertimeEntry extends Equatable {
  /// Creates an overtime entry.
  const EmployeeOvertimeEntry({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.workedDate,
    required this.hours,
    required this.hourRateInCents,
    required this.totalInCents,
    required this.status,
    required this.createdAt,
    this.note,
    this.payrollRunId,
    this.payrollRunLineId,
  });

  /// Stable identifier.
  final String id;

  /// Employee identifier.
  final String employeeId;

  /// Employee display name.
  final String employeeName;

  /// Day when overtime was worked.
  final DateTime workedDate;

  /// Number of overtime hours.
  final double hours;

  /// Hour rate captured at registration time.
  final int hourRateInCents;

  /// Total overtime amount.
  final int totalInCents;

  /// Optional note.
  final String? note;

  /// Entry state: pending or paid.
  final String status;

  /// Payroll run if paid.
  final String? payrollRunId;

  /// Payroll line if paid.
  final String? payrollRunLineId;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Whether the entry can still be edited or deleted.
  bool get isPending => status == 'pending';

  @override
  List<Object?> get props => [
    id,
    employeeId,
    employeeName,
    workedDate,
    hours,
    hourRateInCents,
    totalInCents,
    note,
    status,
    payrollRunId,
    payrollRunLineId,
    createdAt,
  ];
}
