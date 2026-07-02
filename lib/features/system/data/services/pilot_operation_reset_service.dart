import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';

/// Result summary for a pilot operation reset.
final class PilotOperationResetSummary {
  /// Creates a pilot reset summary.
  const PilotOperationResetSummary({
    required this.localRows,
    required this.remoteRows,
  });

  /// Local operational rows removed or reset.
  final int localRows;

  /// Remote operational rows removed or reset.
  final int remoteRows;
}

/// Clears pilot operational data while keeping catalogs and configuration.
final class PilotOperationResetService {
  /// Creates the pilot reset service.
  const PilotOperationResetService({
    required AppDatabase database,
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
  }) : _database = database,
       _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client;

  /// Exact confirmation required to execute the irreversible reset.
  static const confirmationText = 'REINICIAR PRODUCCION';

  final AppDatabase _database;
  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;

  /// Deletes sales/cash/expenses and resets stock for production start.
  Future<AppResult<PilotOperationResetSummary>> resetPilotOperation({
    required String confirmation,
  }) async {
    try {
      final normalizedConfirmation = confirmation.trim();
      if (normalizedConfirmation != confirmationText) {
        return const AppFailureResult(
          AppFailure(
            code: 'invalid_pilot_reset_confirmation',
            message:
                'Para ejecutar el cierre debes escribir exactamente '
                '$confirmationText.',
          ),
        );
      }

      final remoteRows = await _resetRemote(normalizedConfirmation);
      final localRows = await _resetLocal();
      return AppSuccess(
        PilotOperationResetSummary(
          localRows: localRows,
          remoteRows: remoteRows,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'pilot_operation_reset_failed',
          message:
              'No se pudo cerrar la operacion piloto. No se marco como '
              'completada.',
          cause: error,
        ),
      );
    }
  }

  Future<int> _resetRemote(String confirmation) async {
    final token = _remoteSessionService.accessToken;
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        token == null) {
      throw StateError(
        'Se requiere conexion y sesion administrativa remota.',
      );
    }

    final response = await _client.post(
      _config.rpcUri('reset_pilot_operation'),
      headers: {
        'apikey': _config.publishableKey,
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'p_restaurant_id': _restaurantService.restaurantId,
        'p_confirmation': confirmation,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Supabase rechazo cierre de piloto (${response.statusCode}): '
        '${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) {
      return _int(decoded['total_rows']);
    }
    return 0;
  }

  Future<int> _resetLocal() {
    return _database.transaction(() async {
      final rowsBefore = await _countOperationalRows();
      final now = DateTime.now();

      await _database.delete(_database.localSyncQueue).go();
      await _database.delete(_database.localPosOpenTicketLines).go();
      await _database.delete(_database.localPosOrderContexts).go();
      await _database.delete(_database.localSaleVoids).go();
      await _database.delete(_database.localSaleItems).go();
      await _database.delete(_database.localSales).go();
      await _database.delete(_database.localOperatingExpenses).go();
      await _database.delete(_database.localTableAccounts).go();
      await _database.delete(_database.localCashRegisterSessions).go();
      await _database.delete(_database.localInventoryMovements).go();
      await _database.delete(_database.localPackagingMovements).go();

      await _database
          .update(_database.localInventoryStock)
          .write(
            LocalInventoryStockCompanion(
              quantityOnHand: const Value(0),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
          );
      await _database
          .update(_database.localPackagingStock)
          .write(
            LocalPackagingStockCompanion(
              quantityOnHand: const Value(0),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
          );
      await _database
          .update(_database.localRestaurantTables)
          .write(
            LocalRestaurantTablesCompanion(
              status: const Value('available'),
              displayName: const Value(null),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
          );

      final settings = await _database
          .select(_database.localBusinessSettings)
          .getSingleOrNull();
      if (settings != null) {
        await (_database.update(
          _database.localBusinessSettings,
        )..where((table) => table.id.equals(settings.id))).write(
          LocalBusinessSettingsCompanion(
            nextInvoiceNumber: Value(settings.initialInvoiceNumber),
            syncStatus: const Value('synced'),
            syncError: const Value(null),
            updatedAt: Value(now),
            syncedAt: Value(now),
          ),
        );
      }

      return rowsBefore;
    });
  }

  Future<int> _countOperationalRows() async {
    var total = 0;
    for (final table in _operationalTables) {
      total += await _count(table);
    }
    return total;
  }

  Future<int> _count(String tableName) async {
    final row = await _database
        .customSelect('SELECT COUNT(*) AS row_count FROM $tableName')
        .getSingle();
    return _int(row.data['row_count']);
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static const _operationalTables = [
    'local_sync_queue',
    'local_pos_open_ticket_lines',
    'local_pos_order_contexts',
    'local_sale_voids',
    'local_sale_items',
    'local_sales',
    'local_operating_expenses',
    'local_table_accounts',
    'local_cash_register_sessions',
    'local_inventory_movements',
    'local_packaging_movements',
  ];
}
