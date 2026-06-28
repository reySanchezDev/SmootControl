import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/open_database_connection_stub.dart'
    if (dart.library.io) 'package:smoo_control/core/database/open_database_connection_io.dart'
    if (dart.library.js_interop) 'package:smoo_control/core/database/open_database_connection_web.dart';

/// Opens the platform-specific local database connection.
QueryExecutor openDatabaseConnection() {
  return createDatabaseConnection();
}
