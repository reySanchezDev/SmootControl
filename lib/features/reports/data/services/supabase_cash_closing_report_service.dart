import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/core/utils/business_date_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/cash_closing_report.dart';

part 'supabase_cash_closing_report_helpers_part.dart';

/// Builds cash closing reports directly from Supabase.
final class SupabaseCashClosingReportService {
  /// Creates a Supabase cash closing report service.
  const SupabaseCashClosingReportService({
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

  /// Loads one cash closing report for an inclusive date range.
  Future<AppResult<CashClosingReport>> load({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_isConfigured) return const AppFailureResult(_notConfigured);
    final safeFrom = _dateOnly(from);
    final safeTo = _dateOnly(to);
    if (safeTo.isBefore(safeFrom)) {
      return const AppFailureResult(
        AppFailure(
          code: 'cash_closing_invalid_range',
          message: 'La fecha final no puede ser menor que la fecha inicial.',
        ),
      );
    }

    try {
      final sessions = await _loadSessions(from: safeFrom, to: safeTo);
      final ids = sessions.map((session) => session.id).toSet();
      final methods = await _loadPaymentMethods();
      final users = await _loadProfiles(sessions.map((e) => e.cashierId));
      final devices = await _loadDevices(sessions.map((e) => e.deviceId));
      final categories = await _loadExpenseCategories();
      final sales = await _loadSales(ids);
      final expenses = await _loadExpenses(ids);

      final salesBySession = _groupSales(sales, methods);
      final expensesBySession = _groupExpenses(expenses, categories);
      final reportSessions = sessions.map((session) {
        return CashClosingSessionReport(
          businessDate: session.businessDate,
          cashExpenses: expensesBySession[session.id] ?? const [],
          cashierName: users[session.cashierId] ?? 'Cajero',
          deviceName: devices[session.deviceId] ?? 'POS',
          hasPhysicalCount: session.hasPhysicalCount,
          id: session.id,
          methodTotals: salesBySession[session.id] ?? const [],
          openingCashInCents: session.openingCashInCents,
          physicalCashInCents: session.physicalCashInCents,
          saleCount: sales.where((sale) => sale.sessionId == session.id).length,
          status: session.status,
        );
      }).toList();

      return AppSuccess(
        CashClosingReport(
          from: safeFrom,
          generatedAt: DateTime.now(),
          sessions: reportSessions,
          to: safeTo,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'cash_closing_report_failed',
          message: 'No se pudo consultar el arqueo de caja.',
          cause: error,
        ),
      );
    }
  }

  Future<List<_RemoteCashSession>> _loadSessions({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _getRows('cash_register_sessions', {
      'select':
          'id,cashier_user_id,pos_device_id,business_date,'
          'opening_cash_amount,counted_cash_amount,status',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'business_date': 'gte.${BusinessDateFormatter.format(from)}',
      'and': '(business_date.lte.${BusinessDateFormatter.format(to)})',
      'order': 'business_date.desc,opened_at.desc',
    });

    return rows.map((row) {
      return _RemoteCashSession(
        id: _text(row, 'id'),
        cashierId: _text(row, 'cashier_user_id'),
        deviceId: _optionalText(row['pos_device_id']),
        businessDate: DateTime.parse(_text(row, 'business_date')),
        openingCashInCents: _moneyToCents(row['opening_cash_amount']),
        hasPhysicalCount: row['counted_cash_amount'] != null,
        physicalCashInCents: _moneyToCents(row['counted_cash_amount']),
        status: row['status']?.toString() ?? 'open',
      );
    }).toList();
  }

  Future<List<_RemoteSale>> _loadSales(Set<String> sessionIds) async {
    if (sessionIds.isEmpty) return const [];
    final rows = await _getRows('sales', {
      'select': 'id,cash_register_session_id,payment_method_id,total_amount',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'cash_register_session_id': _inFilter(sessionIds),
      'status': 'eq.completed',
      'sale_kind': 'eq.sale',
    });

    return rows.map((row) {
      return _RemoteSale(
        id: _text(row, 'id'),
        methodId: _text(row, 'payment_method_id'),
        sessionId: _text(row, 'cash_register_session_id'),
        totalInCents: _moneyToCents(row['total_amount']),
      );
    }).toList();
  }

  Future<List<_RemoteExpense>> _loadExpenses(Set<String> sessionIds) async {
    if (sessionIds.isEmpty) return const [];
    final rows = await _getRows('operating_expenses', {
      'select':
          'id,expense_category_id,cash_register_session_id,description,'
          'amount,spent_at,affects_cash',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'cash_register_session_id': _inFilter(sessionIds),
      'affects_cash': 'eq.true',
      'order': 'spent_at.desc',
    });

    return rows.map((row) {
      return _RemoteExpense(
        amountInCents: _moneyToCents(row['amount']),
        categoryId: _text(row, 'expense_category_id'),
        description: _optionalText(row['description']) ?? 'Gasto POS',
        sessionId: _text(row, 'cash_register_session_id'),
        spentAt: _dateTime(row['spent_at']),
      );
    }).toList();
  }

  Future<Map<String, _RemotePaymentMethod>> _loadPaymentMethods() async {
    final restaurantFilter =
        '(restaurant_id.eq.${_restaurantService.restaurantId},'
        'restaurant_id.is.null)';
    final rows = await _getRows('payment_methods', {
      'select': 'id,name,group_name,affects_cash',
      'or': restaurantFilter,
    });

    return {
      for (final row in rows)
        _text(row, 'id'): _RemotePaymentMethod(
          affectsCash: row['affects_cash'] == true,
          groupName: row['group_name']?.toString() ?? 'Otros',
          name: row['name']?.toString() ?? 'Metodo',
        ),
    };
  }

  Future<Map<String, String>> _loadProfiles(Iterable<String> ids) async {
    final values = ids.where((id) => id.isNotEmpty).toSet();
    if (values.isEmpty) return const {};
    final rows = await _getRows('profiles', {
      'select': 'id,display_name,email',
      'id': _inFilter(values),
    });
    return {
      for (final row in rows)
        _text(row, 'id'):
            _optionalText(row['display_name']) ??
            _optionalText(row['email']) ??
            'Cajero',
    };
  }

  Future<Map<String, String>> _loadDevices(Iterable<String?> ids) async {
    final values = ids.whereType<String>().where((id) => id.isNotEmpty).toSet();
    if (values.isEmpty) return const {};
    final rows = await _getRows('pos_devices', {
      'select': 'id,name',
      'id': _inFilter(values),
    });
    return {
      for (final row in rows)
        _text(row, 'id'): _optionalText(row['name']) ?? 'POS',
    };
  }

  Future<Map<String, String>> _loadExpenseCategories() async {
    final restaurantFilter =
        '(restaurant_id.eq.${_restaurantService.restaurantId},'
        'restaurant_id.is.null)';
    final rows = await _getRows('expense_categories', {
      'select': 'id,name',
      'or': restaurantFilter,
    });
    return {for (final row in rows) _text(row, 'id'): _text(row, 'name')};
  }

  Map<String, List<CashClosingMethodTotal>> _groupSales(
    List<_RemoteSale> sales,
    Map<String, _RemotePaymentMethod> methods,
  ) {
    final totals = <String, Map<String, int>>{};
    for (final sale in sales) {
      final byMethod = totals.putIfAbsent(sale.sessionId, () => {});
      byMethod[sale.methodId] =
          (byMethod[sale.methodId] ?? 0) + sale.totalInCents;
    }

    return totals.map((sessionId, byMethod) {
      final items = byMethod.entries.map((entry) {
        final method = methods[entry.key] ?? const _RemotePaymentMethod();
        return CashClosingMethodTotal(
          affectsCash: method.affectsCash,
          amountInCents: entry.value,
          groupName: method.groupName,
          isTransfer: method.isTransfer,
          name: method.name,
        );
      }).toList()..sort((a, b) => b.amountInCents.compareTo(a.amountInCents));
      return MapEntry(sessionId, items);
    });
  }

  Map<String, List<CashClosingExpenseLine>> _groupExpenses(
    List<_RemoteExpense> expenses,
    Map<String, String> categories,
  ) {
    final grouped = <String, List<CashClosingExpenseLine>>{};
    for (final expense in expenses) {
      grouped
          .putIfAbsent(expense.sessionId, () => [])
          .add(
            CashClosingExpenseLine(
              amountInCents: expense.amountInCents,
              categoryName: categories[expense.categoryId] ?? 'Gasto',
              description: expense.description,
              spentAt: expense.spentAt,
            ),
          );
    }
    return grouped;
  }

  bool get _isConfigured =>
      _config.isConfigured &&
      _restaurantService.isConfigured &&
      _remoteSessionService.hasUsableToken;

  static const _notConfigured = AppFailure(
    code: 'cash_closing_not_configured',
    message: 'Supabase no esta configurado para reportes.',
  );
}
