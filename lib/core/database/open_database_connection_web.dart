import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Opens a persistent Drift database on Web when wasm assets are available.
QueryExecutor createDatabaseConnection() {
  return DatabaseConnection.delayed(_openWebDatabase());
}

Future<DatabaseConnection> _openWebDatabase() async {
  final result = await WasmDatabase.open(
    databaseName: 'smoo_control',
    driftWorkerUri: Uri.parse('drift_worker.js'),
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
  );

  return result.resolvedExecutor;
}
