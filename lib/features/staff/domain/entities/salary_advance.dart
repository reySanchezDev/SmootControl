import 'package:equatable/equatable.dart';

/// Salary advance assigned to an employee.
final class SalaryAdvance extends Equatable {
  /// Creates a salary advance.
  const SalaryAdvance({
    required this.id,
    required this.employeeId,
    required this.amountInCents,
    required this.createdBy,
    required this.createdAt,
    DateTime? deliveredAt,
    this.cashRegisterSessionId,
    this.affectsCash = false,
    this.balanceInCents,
    this.note,
    this.status = 'pending',
  }) : deliveredAt = deliveredAt ?? createdAt;

  /// Unique identifier.
  final String id;

  /// Employee identifier.
  final String employeeId;

  /// Optional POS cash session.
  final String? cashRegisterSessionId;

  /// Amount in minor currency units.
  final int amountInCents;

  /// Pending balance in minor currency units.
  final int? balanceInCents;

  /// Whether the advance reduced POS cash.
  final bool affectsCash;

  /// Optional note.
  final String? note;

  /// User that registered the advance.
  final String createdBy;

  /// Advance state.
  final String status;

  /// Creation time.
  final DateTime createdAt;

  /// Date when the money was delivered to the employee.
  final DateTime deliveredAt;

  @override
  List<Object?> get props => [
    id,
    employeeId,
    cashRegisterSessionId,
    amountInCents,
    balanceInCents,
    affectsCash,
    note,
    createdBy,
    status,
    createdAt,
    deliveredAt,
  ];
}
