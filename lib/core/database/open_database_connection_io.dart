import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens a persistent SQLite database on Android and other IO platforms.
QueryExecutor createDatabaseConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'smoo_control.sqlite'));

    return NativeDatabase.createInBackground(file);
  });
}
