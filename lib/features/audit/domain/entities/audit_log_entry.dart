import 'package:equatable/equatable.dart';

/// Audit log entry for sensitive actions.
final class AuditLogEntry extends Equatable {
  /// Creates an audit log entry.
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.entityName,
    required this.details,
    required this.occurredAt,
    this.actorUserId,
    this.entityId,
  });

  /// Local identifier.
  final String id;

  /// Actor user id when available.
  final String? actorUserId;

  /// Action code.
  final String action;

  /// Entity name.
  final String entityName;

  /// Entity id when available.
  final String? entityId;

  /// JSON-compatible details.
  final Map<String, Object?> details;

  /// Time when the action happened.
  final DateTime occurredAt;

  @override
  List<Object?> get props => [
    id,
    actorUserId,
    action,
    entityName,
    entityId,
    details,
    occurredAt,
  ];
}
