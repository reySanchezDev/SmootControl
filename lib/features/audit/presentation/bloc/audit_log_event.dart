import 'package:equatable/equatable.dart';

/// Base event for audit log state.
sealed class AuditLogEvent extends Equatable {
  /// Creates an audit log event.
  const AuditLogEvent();

  @override
  List<Object?> get props => [];
}

/// Requests audit entries for one date.
final class AuditLogDateRequested extends AuditLogEvent {
  /// Creates an audit date requested event.
  const AuditLogDateRequested(this.date);

  /// Date to inspect.
  final DateTime date;

  @override
  List<Object?> get props => [date];
}
