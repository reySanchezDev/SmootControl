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
      final exclusiveTo = safeTo.add(const Duration(days: 1));
      final sales = await _loadSales(from: safeFrom, exclusiveTo: exclusiveTo);
      final saleIds = sales.map((sale) => sale.id).toSet();
      final items = await _loadSaleItems(saleIds);
      final dateBySaleId = {
        for (final sale in sales) sale.id: _dateOnly(sale.soldAt),
      };
      final rowsByDate = <DateTime, _DailySalesAccumulator>{};

      for (final sale in sales) {
        final date = _dateOnly(sale.soldAt);
        rowsByDate.putIfAbsent(date, _DailySalesAccumulator.new).salesInCents +=
            sale.totalInCents;
      }

      for (final item in items) {
        final date = dateBySaleId[item.saleId];
        if (date == null) continue;
        rowsByDate.putIfAbsent(date, _DailySalesAccumulator.new).costInCents +=
            item.totalCostInCents;
      }

      final rows = rowsByDate.entries.map((entry) {
        return DailySalesReportRow(
          date: entry.key,
          totalCostInCents: entry.value.costInCents,
          totalSalesInCents: entry.value.salesInCents,
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

  Future<List<_RemoteDailySale>> _loadSales({
    required DateTime exclusiveTo,
    required DateTime from,
  }) async {
    final rows = await _getRows('sales', {
      'select': 'id,total_amount,sold_at',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'status': 'eq.completed',
      'sale_kind': 'eq.sale',
      'and': _dateRangeFilter('sold_at', from, exclusiveTo),
      'order': 'sold_at.asc',
    });

    return rows.map((row) {
      return _RemoteDailySale(
        id: _requiredText(row, 'id'),
        soldAt: _dateTime(row['sold_at']),
        totalInCents: _moneyToCents(row['total_amount']),
      );
    }).toList();
  }

  Future<List<_RemoteDailySaleItem>> _loadSaleItems(Set<String> saleIds) async {
    if (saleIds.isEmpty) return const [];

    final rows = await _getRows('sale_items', {
      'select': 'sale_id,quantity,unit_cost',
      'sale_id': _inFilter(saleIds),
    });

    return rows.map((row) {
      final quantity = _quantity(row['quantity']);
      final unitCost = _moneyToCents(row['unit_cost']);
      return _RemoteDailySaleItem(
        saleId: _requiredText(row, 'sale_id'),
        totalCostInCents: (quantity * unitCost).round(),
      );
    }).toList();
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> queryParameters,
  ) async {
    final response = await _client.get(
      _config.restUri(table, queryParameters),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _remoteSessionService.expire();
      }
      throw StateError(
        'Supabase rechazo consulta de $table '
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

  String _dateRangeFilter(String column, DateTime from, DateTime to) {
    return '($column.gte.${from.toUtc().toIso8601String()},'
        '$column.lt.${to.toUtc().toIso8601String()})';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _dateTime(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      throw StateError('Missing remote date.');
    }
    return DateTime.parse(text).toLocal();
  }

  String _inFilter(Set<String> values) => 'in.(${values.join(',')})';

  int _moneyToCents(Object? value) {
    if (value == null) return 0;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value.toString()) ?? 0) * 100).round();
  }

  num _quantity(Object? value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  String _requiredText(Map<String, Object?> row, String key) {
    final value = row[key]?.toString().trim();
    if (value == null || value.isEmpty) {
      throw StateError('Missing required field $key.');
    }
    return value;
  }
}

final class _DailySalesAccumulator {
  int costInCents = 0;
  int salesInCents = 0;
}

final class _RemoteDailySale {
  const _RemoteDailySale({
    required this.id,
    required this.soldAt,
    required this.totalInCents,
  });

  final String id;
  final DateTime soldAt;
  final int totalInCents;
}

final class _RemoteDailySaleItem {
  const _RemoteDailySaleItem({
    required this.saleId,
    required this.totalCostInCents,
  });

  final String saleId;
  final int totalCostInCents;
}
