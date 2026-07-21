import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';

part 'pilot_operation_reset_local_part.dart';
part 'pilot_operation_reset_device_part.dart';
part 'pilot_operation_reset_sql_part.dart';

/// Controlled cleanup scope available from the administrative utilities page.
enum PilotCleanupScope {
  /// Normal POS sales, open tickets, table accounts and sale movements.
  sales,

  /// Operational expenses only.
  expenses,

  /// Salary advances and their technical cash expenses.
  salaryAdvances,

  /// Payroll runs and payroll lines.
  payroll,

  /// Staff consumption receipts and related movements.
  staffConsumptions,

  /// Payroll, staff consumption and salary advances together.
  staffOperations,
}

/// UI/runtime metadata for a cleanup scope.
extension PilotCleanupScopeDetails on PilotCleanupScope {
  /// Exact confirmation required for this cleanup.
  String get confirmationText => switch (this) {
    PilotCleanupScope.sales => 'BORRAR VENTAS',
    PilotCleanupScope.expenses => 'BORRAR GASTOS',
    PilotCleanupScope.salaryAdvances => 'BORRAR ADELANTOS',
    PilotCleanupScope.payroll => 'BORRAR PLANILLA',
    PilotCleanupScope.staffConsumptions => 'BORRAR CONSUMOS',
    PilotCleanupScope.staffOperations => 'BORRAR PERSONAL OPERATIVO',
  };

  /// RPC scope value.
  String get remoteValue => switch (this) {
    PilotCleanupScope.sales => 'sales',
    PilotCleanupScope.expenses => 'expenses',
    PilotCleanupScope.salaryAdvances => 'salary_advances',
    PilotCleanupScope.payroll => 'payroll',
    PilotCleanupScope.staffConsumptions => 'staff_consumptions',
    PilotCleanupScope.staffOperations => 'staff_operations',
  };
}

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

      final localRows = await _resetLocal();
      final remoteRows = await _resetRemote(normalizedConfirmation);
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

  /// Deletes one operational scope locally first and then in Supabase.
  Future<AppResult<PilotOperationResetSummary>> resetScope({
    required PilotCleanupScope scope,
    required String confirmation,
  }) async {
    try {
      final normalizedConfirmation = confirmation.trim();
      if (normalizedConfirmation != scope.confirmationText) {
        return AppFailureResult(
          AppFailure(
            code: 'invalid_pilot_cleanup_confirmation',
            message:
                'Para ejecutar esta limpieza debes escribir exactamente '
                '${scope.confirmationText}.',
          ),
        );
      }

      final localRows = await _resetLocalScope(scope);
      final remoteRows = await _resetRemoteScope(
        confirmation: normalizedConfirmation,
        scope: scope,
      );
      return AppSuccess(
        PilotOperationResetSummary(
          localRows: localRows,
          remoteRows: remoteRows,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'pilot_scope_cleanup_failed',
          message:
              'No se pudo completar la limpieza. La limpieza local se ejecuta '
              'primero para evitar reenvios desde este movil; puedes repetir '
              'la accion para completar Supabase.',
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
      if (response.statusCode == 401 || response.statusCode == 403) {
        _remoteSessionService.expire();
      }
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

  Future<int> _resetRemoteScope({
    required String confirmation,
    required PilotCleanupScope scope,
  }) async {
    final token = _remoteSessionService.accessToken;
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        token == null) {
      throw StateError(
        'Se requiere conexion y sesion administrativa remota.',
      );
    }

    final response = await _client.post(
      _config.rpcUri('reset_pilot_operation_scope'),
      headers: {
        'apikey': _config.publishableKey,
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'p_restaurant_id': _restaurantService.restaurantId,
        'p_confirmation': confirmation,
        'p_scope': scope.remoteValue,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _remoteSessionService.expire();
      }
      throw StateError(
        'Supabase rechazo limpieza ${scope.remoteValue} '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) {
      return _int(decoded['total_rows']);
    }
    return 0;
  }
}
