import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/pos/data/models/pos_open_ticket_line_model.dart';

/// Local datasource for POS tickets that are still open by table.
final class LocalPosOpenTicketDataSource {
  /// Creates a local open ticket datasource.
  const LocalPosOpenTicketDataSource(this._database);

  final AppDatabase _database;

  /// Reads every open ticket line.
  Future<List<PosOpenTicketLineModel>> getOpenTickets() async {
    final query = _database.select(_database.localPosOpenTicketLines)
      ..orderBy([(line) => OrderingTerm.asc(line.createdAt)]);
    final rows = await query.get();
    return rows.map(PosOpenTicketLineModel.fromLocal).toList();
  }

  /// Replaces the stored ticket for a table.
  Future<void> replaceTableTicket({
    required String tableId,
    required List<PosOpenTicketLineModel> lines,
  }) async {
    final now = DateTime.now();
    await _database.transaction(() async {
      await (_database.delete(
        _database.localPosOpenTicketLines,
      )..where((line) => line.tableId.equals(tableId))).go();

      if (lines.isEmpty) return;

      await _database.batch((batch) {
        for (final line in lines) {
          batch.insert(
            _database.localPosOpenTicketLines,
            line.toCompanion(createdAt: now, updatedAt: now),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }
}
