import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_open_ticket_line.dart';

/// Repository for local POS table tickets that have not been invoiced.
abstract interface class IPosOpenTicketRepository {
  /// Reads every locally open table ticket line.
  Future<AppResult<List<PosOpenTicketLine>>> getOpenTickets();

  /// Replaces the currently stored ticket for one table.
  Future<AppResult<void>> saveTableTicket({
    required String tableId,
    required List<PosCartLine> lines,
  });
}
