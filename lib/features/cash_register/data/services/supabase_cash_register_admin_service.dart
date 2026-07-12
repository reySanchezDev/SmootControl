import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/core/utils/business_date_formatter.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_admin_record.dart';

/// Remote administrative service for cash register sessions.
final class SupabaseCashRegisterAdminService {
  /// Creates a Supabase cash register admin service.
  const SupabaseCashRegisterAdminService({
    required http.Client client,
    required SupabaseAppConfig config,
    required CurrentRemoteSessionService remoteSessionService,
    required CurrentRestaurantService restaurantService,
  }) : _client = client,
       _config = config,
       _remoteSessionService = remoteSessionService,
       _restaurantService = restaurantService;

  final http.Client _client;
  final SupabaseAppConfig _config;
  final CurrentRemoteSessionService _remoteSessionService;
  final CurrentRestaurantService _restaurantService;

  /// Loads remote cash register sessions for an inclusive date range.
  Future<AppResult<List<CashRegisterAdminRecord>>> load({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_isConfigured) return const AppFailureResult(_notConfigured);
    try {
      final rows = await _getRows('cash_register_sessions', {
        'select':
            'id,cashier_user_id,business_date,opening_cash_amount,'
            'counted_cash_amount,status,opened_at,closed_at,updated_at',
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'business_date': 'gte.${BusinessDateFormatter.format(from)}',
        'and': '(business_date.lte.${BusinessDateFormatter.format(to)})',
        'order': 'business_date.desc,opened_at.desc',
      });
      return AppSuccess(rows.map(_recordFromRow).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_register_admin_read_failed',
          message: 'No se pudieron consultar las cajas en Supabase.',
          cause: error,
        ),
      );
    }
  }

  /// Updates editable remote cash register fields.
  Future<AppResult<CashRegisterAdminRecord>> update(
    CashRegisterAdminRecord record,
  ) async {
    if (!_isConfigured) return const AppFailureResult(_notConfigured);
    try {
      final body = {
        'opening_cash_amount': _money(record.openingCashInCents),
        'counted_cash_amount': record.physicalClosingCashInCents == null
            ? null
            : _money(record.physicalClosingCashInCents!),
        'status': record.status,
        'closed_at': record.status == 'closed'
            ? record.closedAt?.toIso8601String() ??
                  DateTime.now().toIso8601String()
            : null,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final response = await _client.patch(
        _config.restUri('cash_register_sessions', {'id': 'eq.${record.id}'}),
        headers: _headers(prefer: 'return=representation'),
        body: jsonEncode(body),
      );
      _ensureSuccess(response, 'cash_register_sessions');
      final decoded = jsonDecode(response.body);
      final rows = decoded is List ? decoded : const <Object?>[];
      final first = rows.firstOrNull;
      if (first is! Map<dynamic, dynamic>) {
        throw StateError('Supabase no devolvio la caja actualizada.');
      }
      final row = first.cast<String, Object?>();
      return AppSuccess(_recordFromRow(row));
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_register_admin_update_failed',
          message: 'No se pudo editar la caja en Supabase.',
          cause: error,
        ),
      );
    }
  }

  /// Permanently deletes one remote cash register session.
  Future<AppResult<void>> delete(String id) async {
    if (!_isConfigured) return const AppFailureResult(_notConfigured);
    try {
      final response = await _client.delete(
        _config.restUri('cash_register_sessions', {'id': 'eq.$id'}),
        headers: _headers(),
      );
      _ensureSuccess(response, 'cash_register_sessions');
      return const AppSuccess(null);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_register_admin_delete_failed',
          message: 'No se pudo eliminar la caja en Supabase.',
          cause: error,
        ),
      );
    }
  }

  bool get _isConfigured {
    return _config.isConfigured &&
        _restaurantService.isConfigured &&
        _remoteSessionService.hasUsableToken;
  }

  static const _notConfigured = AppFailure(
    code: 'cash_register_admin_not_configured',
    message: 'Supabase no esta configurado para administrar cajas.',
  );

  Map<String, String> _headers({String? prefer}) {
    final headers = {
      'apikey': _config.publishableKey,
      'Authorization': 'Bearer ${_remoteSessionService.accessToken}',
      'Content-Type': 'application/json',
    };
    if (prefer != null) headers['Prefer'] = prefer;
    return headers;
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> query,
  ) async {
    final response = await _client.get(
      _config.restUri(table, query),
      headers: _headers(),
    );
    _ensureSuccess(response, table);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  CashRegisterAdminRecord _recordFromRow(Map<String, Object?> row) {
    return CashRegisterAdminRecord(
      id: row['id']?.toString() ?? '',
      cashierId: row['cashier_user_id']?.toString() ?? '',
      businessDate: DateTime.parse(row['business_date'].toString()),
      openingCashInCents: _moneyToCents(row['opening_cash_amount']),
      physicalClosingCashInCents: row['counted_cash_amount'] == null
          ? null
          : _moneyToCents(row['counted_cash_amount']),
      status: row['status']?.toString() ?? 'open',
      openedAt: DateTime.parse(row['opened_at'].toString()),
      closedAt: row['closed_at'] == null
          ? null
          : DateTime.parse(row['closed_at'].toString()),
      updatedAt: DateTime.parse(row['updated_at'].toString()),
    );
  }

  void _ensureSuccess(http.Response response, String table) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Supabase rechazo operacion de $table '
        '(${response.statusCode}): ${response.body}',
      );
    }
  }

  String _money(int cents) => (cents / 100).toStringAsFixed(2);

  int _moneyToCents(Object? value) {
    return ((double.tryParse(value?.toString() ?? '') ?? 0) * 100).round();
  }
}
