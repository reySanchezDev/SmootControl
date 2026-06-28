import 'package:equatable/equatable.dart';

/// Supported synchronization operations.
enum SyncOperation {
  /// Remote create operation.
  create,

  /// Remote update operation.
  update,

  /// Remote delete operation.
  delete,
}

/// Local synchronization status.
enum SyncQueueStatus {
  /// Waiting to be synchronized.
  pending,

  /// Currently being synchronized.
  syncing,

  /// Successfully synchronized.
  synced,

  /// Failed and waiting for retry.
  error,
}

/// Local queue item representing a pending remote operation.
final class SyncQueueItem extends Equatable {
  /// Creates a queue item.
  const SyncQueueItem({
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

  /// Local queue identifier.
  final String id;

  /// Entity type, such as `sale` or `expense`.
  final String entityType;

  /// Local entity identifier.
  final String entityId;

  /// Operation to perform remotely.
  final SyncOperation operation;

  /// JSON-compatible payload to send remotely.
  final Map<String, Object?> payload;

  /// Current sync status.
  final SyncQueueStatus status;

  /// Number of failed attempts.
  final int retryCount;

  /// Last sync error, if any.
  final String? lastError;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime updatedAt;

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
