import 'package:drift/drift.dart';

/// Local queue of operations pending remote synchronization.
class LocalSyncQueue extends Table {
  /// Local queue identifier.
  TextColumn get id => text()();

  /// Entity type, such as sale or expense.
  TextColumn get entityType => text()();

  /// Entity local identifier.
  TextColumn get entityId => text()();

  /// create, update or delete.
  TextColumn get operation => text()();

  /// JSON payload to send.
  TextColumn get payloadJson => text()();

  /// pending, syncing, synced or error.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Retry counter.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Last sync error.
  TextColumn get lastError => text().nullable()();

  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime()();

  /// Last update timestamp.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
