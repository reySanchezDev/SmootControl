import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';

/// Base state for audit log.
sealed class AuditLogState extends Equatable {
  /// Creates an audit log state.
  const AuditLogState();

  @override
  List<Object?> get props => [];
}

/// Initial audit state.
final class AuditLogInitial extends AuditLogState {
  /// Creates initial state.
  const AuditLogInitial();
}

/// Loading audit state.
final class AuditLogLoading extends AuditLogState {
  /// Creates loading state.
  const AuditLogLoading();
}

/// Loaded audit state.
final class AuditLogLoaded extends AuditLogState {
  /// Creates loaded state.
  const AuditLogLoaded({
    required this.date,
    required this.entries,
  });

  /// Selected date.
  final DateTime date;

  /// Audit entries.
  final List<AuditLogEntry> entries;

  @override
  List<Object?> get props => [date, entries];
}

/// Failed audit state.
final class AuditLogFailure extends AuditLogState {
  /// Creates failure state.
  const AuditLogFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
