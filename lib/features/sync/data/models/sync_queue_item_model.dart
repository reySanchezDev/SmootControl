import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

/// Data model for local synchronization queue items.
final class SyncQueueItemModel extends Equatable {
  /// Creates a sync queue item model.
  const SyncQueueItemModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  /// Creates a model from a local Drift row.
  factory SyncQueueItemModel.fromLocal(LocalSyncQueueData row) {
    return SyncQueueItemModel(
      id: row.id,
      entityType: row.entityType,
      entityId: row.entityId,
      operation: _operationFromName(row.operation),
      payload: _decodePayload(row.payloadJson),
      status: _statusFromName(row.status),
      retryCount: row.retryCount,
      lastError: row.lastError,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Creates a model from a domain entity.
  factory SyncQueueItemModel.fromEntity(SyncQueueItem entity) {
    return SyncQueueItemModel(
      id: entity.id,
      entityType: entity.entityType,
      entityId: entity.entityId,
      operation: entity.operation,
      payload: entity.payload,
      status: entity.status,
      retryCount: entity.retryCount,
      lastError: entity.lastError,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Local queue identifier.
  final String id;

  /// Entity type.
  final String entityType;

  /// Local entity identifier.
  final String entityId;

  /// Remote operation.
  final SyncOperation operation;

  /// JSON-compatible payload.
  final Map<String, Object?> payload;

  /// Current status.
  final SyncQueueStatus status;

  /// Retry count.
  final int retryCount;

  /// Last error.
  final String? lastError;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime updatedAt;

  /// Encoded payload.
  String get payloadJson => jsonEncode(payload);

  /// Converts this model to an entity.
  SyncQueueItem toEntity() {
    return SyncQueueItem(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      status: status,
      retryCount: retryCount,
      lastError: lastError,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    entityType,
    entityId,
    operation,
    payload,
    status,
    retryCount,
    lastError,
    createdAt,
    updatedAt,
  ];
}

Map<String, Object?> _decodePayload(String value) {
  final decoded = jsonDecode(value);
  if (decoded is Map) {
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }

  return const {};
}

SyncOperation _operationFromName(String value) {
  return SyncOperation.values.firstWhere(
    (operation) => operation.name == value,
    orElse: () => SyncOperation.update,
  );
}

SyncQueueStatus _statusFromName(String value) {
  return SyncQueueStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => SyncQueueStatus.pending,
  );
}
