import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/sync_columns.dart';

/// Local audit log for sensitive business actions.
class LocalAuditLogs extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Actor user identifier when available.
  TextColumn get actorUserId => text().nullable()();

  /// Audited action code.
  TextColumn get action => text()();

  /// Entity type affected by the action.
  TextColumn get entityType => text()();

  /// Entity identifier when available.
  TextColumn get entityId => text().nullable()();

  /// JSON object with contextual details.
  TextColumn get detailsJson => text().withDefault(const Constant('{}'))();

  /// Time when the action happened.
  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
