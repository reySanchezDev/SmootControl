import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/pos/data/datasources/local_pos_open_ticket_datasource.dart';
import 'package:smoo_control/features/pos/data/models/pos_open_ticket_line_model.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_open_ticket_line.dart';
import 'package:smoo_control/features/pos/domain/repositories/i_pos_open_ticket_repository.dart';

/// Repository backed by the local database for POS open tickets.
final class PosOpenTicketRepository implements IPosOpenTicketRepository {
  /// Creates a POS open ticket repository.
  const PosOpenTicketRepository(this._localDataSource);

  final LocalPosOpenTicketDataSource _localDataSource;

  @override
  Future<AppResult<List<PosOpenTicketLine>>> getOpenTickets() async {
    try {
      final rows = await _localDataSource.getOpenTickets();
      return AppSuccess(rows.map((row) => row.toEntity()).toList());
    } on Object {
      return const AppFailureResult(
        AppFailure(
          code: 'pos_open_tickets_read_failed',
          message: 'No se pudieron leer los pedidos abiertos.',
        ),
      );
    }
  }

  @override
  Future<AppResult<Map<String, String>>> getOrderSalesTypes() async {
    try {
      return AppSuccess(await _localDataSource.getOrderSalesTypes());
    } on Object {
      return const AppFailureResult(
        AppFailure(
          code: 'pos_order_context_read_failed',
          message: 'No se pudo leer el tipo de venta del pedido abierto.',
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> saveOrderSalesType({
    required String orderKey,
    required String salesTypeId,
  }) async {
    try {
      await _localDataSource.saveOrderSalesType(
        orderKey: orderKey,
        salesTypeId: salesTypeId,
      );
      return const AppSuccess<void>(null);
    } on Object {
      return const AppFailureResult(
        AppFailure(
          code: 'pos_order_context_save_failed',
          message: 'No se pudo guardar el tipo de venta del pedido.',
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> clearOrderContext(String orderKey) async {
    try {
      await _localDataSource.clearOrderContext(orderKey);
      return const AppSuccess<void>(null);
    } on Object {
      return const AppFailureResult(
        AppFailure(
          code: 'pos_order_context_clear_failed',
          message: 'No se pudo limpiar el tipo de venta del pedido.',
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> saveTableTicket({
    required String tableId,
    required List<PosCartLine> lines,
  }) async {
    try {
      await _localDataSource.replaceTableTicket(
        tableId: tableId,
        lines: [
          for (final line in lines)
            PosOpenTicketLineModel.fromLine(tableId: tableId, line: line),
        ],
      );
      return const AppSuccess<void>(null);
    } on Object {
      return const AppFailureResult(
        AppFailure(
          code: 'pos_open_ticket_save_failed',
          message: 'No se pudo guardar el pedido abierto.',
        ),
      );
    }
  }
}
