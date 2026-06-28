import 'package:drift/drift.dart';

/// Shared local sync metadata for offline-first tables.
mixin SyncColumns on Table {
  /// Remote Supabase identifier when the row has been synced.
  TextColumn get remoteId => text().nullable()();

  /// Local sync state.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Last sync error, if any.
  TextColumn get syncError => text().nullable()();

  /// Local creation timestamp.
  DateTimeColumn get createdAt => dateTime()();

  /// Local update timestamp.
  DateTimeColumn get updatedAt => dateTime()();

  /// Last successful sync timestamp.
  DateTimeColumn get syncedAt => dateTime().nullable()();
}
