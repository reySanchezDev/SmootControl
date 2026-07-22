import 'package:equatable/equatable.dart';

/// Restaurant employee managed by admin and selectable in POS.
final class Employee extends Equatable {
  /// Creates an employee.
  const Employee({
    required this.id,
    required this.fullName,
    this.code,
    this.positionName,
    this.baseSalaryInCents = 0,
    this.isActive = true,
    this.photoUrl,
    this.showInTimeClock = true,
  });

  /// Unique identifier.
  final String id;

  /// Optional visible code.
  final String? code;

  /// Employee display name.
  final String fullName;

  /// Optional position label.
  final String? positionName;

  /// Base salary in minor currency units.
  final int baseSalaryInCents;

  /// Whether employee can be used.
  final bool isActive;

  /// Optional photo URL/path for the attendance kiosk.
  final String? photoUrl;

  /// Whether employee appears in the attendance kiosk.
  final bool showInTimeClock;

  @override
  List<Object?> get props => [
    id,
    code,
    fullName,
    positionName,
    baseSalaryInCents,
    isActive,
    photoUrl,
    showInTimeClock,
  ];
}
