import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/domain/entities/expenses_report.dart';

/// Builds operational expenses reports directly from Supabase.
final class SupabaseExpensesReportService {
  /// Creates a Supabase expenses report service.
  const SupabaseExpensesReportService({
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

  /// Loads operational expenses for an inclusive date range.
  Future<AppResult<ExpensesReport>> load({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        !_remoteSessionService.hasUsableToken) {
      return const AppFailureResult(
        AppFailure(
          code: 'expenses_report_not_configured',
          message: 'Supabase no esta configurado para reportes.',
        ),
      );
    }

    final safeFrom = _dateOnly(from);
    final safeTo = _dateOnly(to);
    if (safeTo.isBefore(safeFrom)) {
      return const AppFailureResult(
        AppFailure(
          code: 'expenses_report_invalid_range',
          message: 'La fecha final no puede ser menor que la fecha inicial.',
        ),
      );
    }

    try {
      final exclusiveTo = safeTo.add(const Duration(days: 1));
      final categories = await _loadCategories();
      final expenses = await _loadExpenses(
        from: safeFrom,
        exclusiveTo: exclusiveTo,
      );
      final rowsByDate = <DateTime, int>{};
      final totalsByCategory = <String, int>{};

      for (final expense in expenses) {
        final date = _dateOnly(expense.spentAt);
        rowsByDate.update(
          date,
          (current) => current + expense.amountInCents,
          ifAbsent: () => expense.amountInCents,
        );
        totalsByCategory.update(
          expense.categoryId,
          (current) => current + expense.amountInCents,
          ifAbsent: () => expense.amountInCents,
        );
      }

      final dailyRows = rowsByDate.entries.map((entry) {
        return DailyExpensesReportRow(
          date: entry.key,
          totalInCents: entry.value,
        );
      }).toList()..sort((a, b) => a.date.compareTo(b.date));

      final categoryRows = totalsByCategory.entries.map((entry) {
        return ExpenseCategoryReportRow(
          categoryId: entry.key,
          categoryName: categories[entry.key] ?? 'Sin categoria',
          totalInCents: entry.value,
        );
      }).toList()..sort((a, b) => b.totalInCents.compareTo(a.totalInCents));

      return AppSuccess(
        ExpensesReport(
          byCategory: categoryRows,
          from: safeFrom,
          rows: dailyRows,
          to: safeTo,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'expenses_report_failed',
          message: 'No se pudo consultar el reporte de gastos.',
          cause: error,
        ),
      );
    }
  }

  Future<List<_RemoteExpense>> _loadExpenses({
    required DateTime exclusiveTo,
    required DateTime from,
  }) async {
    final rows = await _getRows('operating_expenses', {
      'select': 'id,expense_category_id,amount,description,spent_at',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'expense_kind': 'eq.operational',
      'and': _dateRangeFilter('spent_at', from, exclusiveTo),
      'order': 'spent_at.asc',
    });

    return rows.map((row) {
      return _RemoteExpense(
        id: _requiredText(row, 'id'),
        categoryId: _requiredText(row, 'expense_category_id'),
        amountInCents: _moneyToCents(row['amount']),
        description: _optionalText(row['description']) ?? '',
        spentAt: _dateTime(row['spent_at']),
      );
    }).toList();
  }

  Future<Map<String, String>> _loadCategories() async {
    final restaurantFilter =
        '(restaurant_id.eq.${_restaurantService.restaurantId},'
        'restaurant_id.is.null)';
    final rows = await _getRows('expense_categories', {
      'select': 'id,name',
      'or': restaurantFilter,
    });

    return {
      for (final row in rows)
        _requiredText(row, 'id'): _requiredText(row, 'name'),
    };
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

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _dateTime(Object? value) {
    final text = _optionalText(value);
    if (text == null) throw StateError('Missing remote date.');
    return DateTime.parse(text).toLocal();
  }

  int _moneyToCents(Object? value) {
    if (value == null) return 0;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value.toString()) ?? 0) * 100).round();
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

final class _RemoteExpense {
  const _RemoteExpense({
    required this.amountInCents,
    required this.categoryId,
    required this.description,
    required this.id,
    required this.spentAt,
  });

  final int amountInCents;
  final String categoryId;
  final String description;
  final String id;
  final DateTime spentAt;
}
