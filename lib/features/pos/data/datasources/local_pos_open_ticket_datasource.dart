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

  /// Reads selected sales type by open order key.
  Future<Map<String, String>> getOrderSalesTypes() async {
    final rows = await _database.select(_database.localPosOrderContexts).get();
    return {
      for (final row in rows) row.orderKey: row.salesTypeId,
    };
  }

  /// Saves selected sales type for one open order.
  Future<void> saveOrderSalesType({
    required String orderKey,
    required String salesTypeId,
  }) async {
    final now = DateTime.now();
    await _database
        .into(_database.localPosOrderContexts)
        .insertOnConflictUpdate(
          LocalPosOrderContextsCompanion.insert(
            orderKey: orderKey,
            salesTypeId: salesTypeId,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Clears one open order context.
  Future<void> clearOrderContext(String orderKey) async {
    await (_database.delete(
      _database.localPosOrderContexts,
    )..where((context) => context.orderKey.equals(orderKey))).go();
  }

  /// Clears every open ticket line and order context.
  Future<void> clearAllOpenOrders() async {
    await _database.transaction(() async {
      await _database.delete(_database.localPosOpenTicketLines).go();
      await _database.delete(_database.localPosOrderContexts).go();
    });
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
