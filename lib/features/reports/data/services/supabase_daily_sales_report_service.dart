import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/domain/entities/daily_sales_report.dart';

/// Builds the daily sales report directly from Supabase.
final class SupabaseDailySalesReportService {
  /// Creates a Supabase daily sales report service.
  const SupabaseDailySalesReportService({
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

  /// Loads daily sales rows for an inclusive date range.
  Future<AppResult<DailySalesReport>> load({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        !_remoteSessionService.hasUsableToken) {
      return const AppFailureResult(
        AppFailure(
          code: 'daily_sales_report_not_configured',
          message: 'Supabase no esta configurado para reportes.',
        ),
      );
    }

    final safeFrom = _dateOnly(from);
    final safeTo = _dateOnly(to);
    if (safeTo.isBefore(safeFrom)) {
      return const AppFailureResult(
        AppFailure(
          code: 'daily_sales_report_invalid_range',
          message: 'La fecha final no puede ser menor que la fecha inicial.',
        ),
      );
    }

    try {
      final reportRows = await _loadRows(safeFrom, safeTo);
      final rows = reportRows.map((entry) {
        return DailySalesReportRow(
          date: _dateOnly(_dateTime(entry['date'])),
          totalCostInCents: _moneyToCents(entry['cost_amount']),
          totalSalesInCents: _moneyToCents(entry['sales_amount']),
        );
      }).toList()..sort((a, b) => a.date.compareTo(b.date));

      return AppSuccess(
        DailySalesReport(from: safeFrom, to: safeTo, rows: rows),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'daily_sales_report_failed',
          message: 'No se pudo consultar el reporte de ventas al dia.',
          cause: error,
        ),
      );
    }
  }

  Future<List<Map<String, Object?>>> _loadRows(DateTime from, DateTime to) {
    return _rpcRows('app_get_daily_sales_report', {
      'p_restaurant_id': _restaurantService.restaurantId,
      'p_from': _dateParam(from),
      'p_to': _dateParam(to),
      'p_timezone': 'America/Managua',
    });
  }

  Future<List<Map<String, Object?>>> _rpcRows(
    String functionName,
    Map<String, Object?> payload,
  ) async {
    final response = await _client.post(
      _config.rpcUri(functionName),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _remoteSessionService.expire();
      }
      throw StateError(
        'Supabase rechazo consulta de $functionName '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Map<String, String> _headers() {
    return {
      'apikey': _config.publishableKey,
      'Authorization': 'Bearer ${_remoteSessionService.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dateParam(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  DateTime _dateTime(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      throw StateError('Missing remote date.');
    }
    return DateTime.parse(text).toLocal();
  }

  int _moneyToCents(Object? value) {
    if (value == null) return 0;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value.toString()) ?? 0) * 100).round();
  }
}
