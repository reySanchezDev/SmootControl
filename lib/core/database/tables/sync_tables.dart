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

/// Local synchronization runtime configuration.
class LocalSyncSettings extends Table {
  /// Single settings row identifier managed by the system.
  TextColumn get id => text().withDefault(const Constant('default'))();

  /// Whether periodic automatic sync is enabled.
  BoolColumn get autoSyncEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Interval in minutes used by the automatic scheduler.
  IntColumn get intervalMinutes => integer().withDefault(const Constant(5))();

  /// Whether the app should process the queue after startup.
  BoolColumn get syncOnStartup => boolean().withDefault(const Constant(true))();

  /// Whether each new queued item should try to sync immediately.
  BoolColumn get syncOnSave => boolean().withDefault(const Constant(true))();

  /// Last settings update timestamp.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
