import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/domain/entities/product_performance_report.dart';

part 'supabase_product_performance_models_part.dart';

/// Builds product sales and profitability reports from Supabase.
final class SupabaseProductPerformanceReportService {
  /// Creates the service.
  const SupabaseProductPerformanceReportService({
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

  /// Loads product performance for an inclusive date range.
  Future<AppResult<ProductPerformanceReport>> load({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        !_remoteSessionService.hasUsableToken) {
      return const AppFailureResult(
        AppFailure(
          code: 'product_performance_report_not_configured',
          message: 'Supabase no esta configurado para reportes.',
        ),
      );
    }

    final safeFrom = _dateOnly(from);
    final safeTo = _dateOnly(to);
    if (safeTo.isBefore(safeFrom)) {
      return const AppFailureResult(
        AppFailure(
          code: 'product_performance_report_invalid_range',
          message: 'La fecha final no puede ser menor que la fecha inicial.',
        ),
      );
    }

    try {
      final rows = _withDecisionSegments(await _loadRows(safeFrom, safeTo));
      return AppSuccess(
        ProductPerformanceReport(from: safeFrom, to: safeTo, rows: rows),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'product_performance_report_failed',
          message: 'No se pudo consultar el desempeno de productos.',
          cause: error,
        ),
      );
    }
  }

  Future<List<ProductPerformanceRow>> _loadRows(
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _rpcRows('app_get_product_performance_report', {
      'p_restaurant_id': _restaurantService.restaurantId,
      'p_from': _dateParam(from),
      'p_to': _dateParam(to),
    });
    return rows.map((row) {
      return ProductPerformanceRow(
        categoryName: _requiredText(row, 'category_name'),
        costInCents: _moneyToCents(row['cost_amount']),
        grossProfitInCents: _moneyToCents(row['gross_profit_amount']),
        productId: _requiredText(row, 'product_id'),
        productName: _requiredText(row, 'product_name'),
        quantitySold: _quantity(row['quantity_sold']),
        salesInCents: _moneyToCents(row['sales_amount']),
        segment: 'Rentable',
      );
    }).toList();
  }

  List<ProductPerformanceRow> _withDecisionSegments(
    List<ProductPerformanceRow> rows,
  ) {
    final averages = _PerformanceAverages.from(rows);
    return rows.map((row) {
      return row.copyWith(segment: _segment(row, averages));
    }).toList()..sort((a, b) {
      final profit = b.grossProfitInCents.compareTo(a.grossProfitInCents);
      if (profit != 0) return profit;
      return b.quantitySold.compareTo(a.quantitySold);
    });
  }

  String _segment(ProductPerformanceRow row, _PerformanceAverages averages) {
    if (row.grossProfitInCents <= 0 || row.margin < 0.15) return 'Revisar';
    if (row.quantitySold >= averages.quantity &&
        row.grossProfitInCents >= averages.profit) {
      return 'Estrella';
    }
    if (row.quantitySold < averages.quantity && row.margin >= averages.margin) {
      return 'Oportunidad';
    }
    if (row.quantitySold >= averages.quantity && row.margin < averages.margin) {
      return 'Volumen';
    }
    return 'Rentable';
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

  Map<String, String> _headers() => {
    'apikey': _config.publishableKey,
    'Authorization': 'Bearer ${_remoteSessionService.accessToken}',
    'Content-Type': 'application/json',
  };

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _dateParam(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  int _moneyToCents(Object? value) {
    if (value is int) return value * 100;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value?.toString() ?? '') ?? 0) * 100).round();
  }

  double _quantity(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _requiredText(Map<String, Object?> row, String key) {
    final value = _optionalText(row[key]);
    if (value == null) throw StateError('Missing required field $key.');
    return value;
  }
}
