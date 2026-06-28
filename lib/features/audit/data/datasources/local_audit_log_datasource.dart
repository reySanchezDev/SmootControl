import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/audit/data/models/audit_log_entry_model.dart';

/// Local datasource for audit logs.
final class LocalAuditLogDataSource {
  /// Creates a local audit log datasource.
  const LocalAuditLogDataSource(this._database);

  final AppDatabase _database;

  /// Saves an audit entry.
  Future<AuditLogEntryModel> saveEntry(AuditLogEntryModel entry) async {
    final now = DateTime.now();
    await _database
        .into(_database.localAuditLogs)
        .insertOnConflictUpdate(
          LocalAuditLogsCompanion(
            id: Value(entry.id),
            actorUserId: Value(entry.actorUserId),
            action: Value(entry.action),
            entityType: Value(entry.entityName),
            entityId: Value(entry.entityId),
            detailsJson: Value(entry.detailsJson),
            occurredAt: Value(entry.occurredAt),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return entry;
  }

  /// Returns audit entries by date.
  Future<List<AuditLogEntryModel>> getEntriesByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final query = _database.select(_database.localAuditLogs)
      ..where((entry) => entry.occurredAt.isBiggerOrEqualValue(start))
      ..where((entry) => entry.occurredAt.isSmallerThanValue(end))
      ..orderBy([(entry) => OrderingTerm.desc(entry.occurredAt)]);
    final rows = await query.get();

    return rows.map(AuditLogEntryModel.fromLocal).toList();
  }
}
