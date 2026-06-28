import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/data/datasources/local_audit_log_datasource.dart';
import 'package:smoo_control/features/audit/data/models/audit_log_entry_model.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';

/// Audit log repository backed by the local offline database.
final class AuditLogRepository implements IAuditLogRepository {
  /// Creates an audit log repository.
  const AuditLogRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
  }) : _syncQueueRepository = syncQueueRepository;

  final LocalAuditLogDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;

  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    try {
      final entries = await _localDataSource.getEntriesByDate(date);
      return AppSuccess(entries.map((entry) => entry.toEntity()).toList());
    } on Object catch (error) {
      return _failure('audit_read_failed', 'No se pudo leer auditoria.', error);
    }
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    try {
      final model = AuditLogEntryModel.fromEntity(entry);
      final saved = await _localDataSource.saveEntry(model);
      final entity = saved.toEntity();
      await _enqueueAuditEntry(entity);

      return AppSuccess(entity);
    } on Object catch (error) {
      return _failure(
        'audit_save_failed',
        'No se pudo guardar auditoria.',
        error,
      );
    }
  }

  AppFailureResult<T> _failure<T>(
    String code,
    String message,
    Object error,
  ) {
    return AppFailureResult(
      AppFailure(code: code, message: message, cause: error),
    );
  }

  Future<void> _enqueueAuditEntry(AuditLogEntry entry) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'audit_logs',
      entityId: entry.id,
      operation: SyncOperation.create,
      payload: {
        'id': entry.id,
        'actorUserId': entry.actorUserId,
        'action': entry.action,
        'entityName': entry.entityName,
        'entityId': entry.entityId,
        'details': entry.details,
        'occurredAt': entry.occurredAt.toIso8601String(),
      },
    );
  }
}
