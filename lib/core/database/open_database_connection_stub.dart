import 'package:drift/drift.dart';

/// Fallback for unsupported platforms.
QueryExecutor createDatabaseConnection() {
  throw UnsupportedError('No local database connection for this platform.');
}
