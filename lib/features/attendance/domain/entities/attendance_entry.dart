import 'package:equatable/equatable.dart';

/// Employee attendance record for one work day.
final class AttendanceEntry extends Equatable {
  /// Creates an attendance entry.
  const AttendanceEntry({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.workDate,
    required this.status,
    required this.source,
    required this.verificationMethod,
    required this.createdAt,
    this.clockInAt,
    this.clockOutAt,
    this.note,
    this.deviceName,
  });

  /// Stable local or remote identifier.
  final String id;

  /// Employee identifier.
  final String employeeId;

  /// Employee display name.
  final String employeeName;

  /// Business work day.
  final DateTime workDate;

  /// Entry timestamp.
  final DateTime? clockInAt;

  /// Exit timestamp.
  final DateTime? clockOutAt;

  /// open, closed or voided.
  final String status;

  /// time_clock or admin.
  final String source;

  /// V1 uses photo_tap.
  final String verificationMethod;

  /// Optional admin/operator note.
  final String? note;

  /// Friendly device name, when remote can resolve it.
  final String? deviceName;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Whether the work shift is open.
  bool get isOpen => status == 'open';

  @override
  List<Object?> get props => [
    id,
    employeeId,
    employeeName,
    workDate,
    clockInAt,
    clockOutAt,
    status,
    source,
    verificationMethod,
    note,
    deviceName,
    createdAt,
  ];
}
