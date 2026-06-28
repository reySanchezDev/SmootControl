import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';

/// Data model for local audit logs.
final class AuditLogEntryModel extends Equatable {
  /// Creates an audit log model.
  const AuditLogEntryModel({
    required this.id,
    required this.action,
    required this.entityName,
    required this.details,
    required this.occurredAt,
    this.actorUserId,
    this.entityId,
  });

  /// Creates a model from a local row.
  factory AuditLogEntryModel.fromLocal(LocalAuditLog row) {
    return AuditLogEntryModel(
      id: row.id,
      actorUserId: row.actorUserId,
      action: row.action,
      entityName: row.entityType,
      entityId: row.entityId,
      details: _decodeDetails(row.detailsJson),
      occurredAt: row.occurredAt,
    );
  }

  /// Creates a model from a domain entity.
  factory AuditLogEntryModel.fromEntity(AuditLogEntry entity) {
    return AuditLogEntryModel(
      id: entity.id,
      actorUserId: entity.actorUserId,
      action: entity.action,
      entityName: entity.entityName,
      entityId: entity.entityId,
      details: entity.details,
      occurredAt: entity.occurredAt,
    );
  }

  /// Local identifier.
  final String id;

  /// Actor user id.
  final String? actorUserId;

  /// Action code.
  final String action;

  /// Entity name.
  final String entityName;

  /// Entity id.
  final String? entityId;

  /// Context details.
  final Map<String, Object?> details;

  /// Time when the action happened.
  final DateTime occurredAt;

  /// Encoded details.
  String get detailsJson => jsonEncode(details);

  /// Converts this model to a domain entity.
  AuditLogEntry toEntity() {
    return AuditLogEntry(
      id: id,
      actorUserId: actorUserId,
      action: action,
      entityName: entityName,
      entityId: entityId,
      details: details,
      occurredAt: occurredAt,
    );
  }

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

Map<String, Object?> _decodeDetails(String value) {
  final decoded = jsonDecode(value);
  if (decoded is Map) {
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }

  return const {};
}
