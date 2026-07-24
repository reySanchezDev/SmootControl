import 'package:equatable/equatable.dart';

/// Work shift assigned to employees for attendance reporting.
final class EmployeeWorkShift extends Equatable {
  /// Creates a work shift.
  const EmployeeWorkShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  /// Remote identifier.
  final String id;

  /// Shift display name.
  final String name;

  /// Expected entry time, formatted as HH:mm.
  final String startTime;

  /// Expected exit time, formatted as HH:mm.
  final String endTime;

  /// Whether this shift can be assigned.
  final bool isActive;

  @override
  List<Object?> get props => [id, name, startTime, endTime, isActive];
}
