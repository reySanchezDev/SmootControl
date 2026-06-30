import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/core/utils/business_date_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/report_period.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';
import 'package:smoo_control/features/reports/domain/services/i_remote_report_summary_service.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';

/// Builds administrative report summaries directly from Supabase.
final class SupabaseReportSummaryService
    implements IRemoteReportSummaryService {
  /// Creates a Supabase-backed report service.
  SupabaseReportSummaryService({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required http.Client client,
  }) : _config = config,
       _restaurantService = restaurantService,
       _client = client;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final http.Client _client;

  String? _accessToken;
  DateTime? _expiresAt;

  @override
  bool get isConfigured => _config.isConfigured;

  @override
  Future<AppResult<ReportSummary>> loadSummaryForRange(
    ReportDateRange range,
  ) async {
    if (!isConfigured) {
      return const AppFailureResult(
        AppFailure(
          code: 'remote_reports_not_configured',
          message: 'Supabase no esta configurado para reportes.',
        ),
      );
    }

    try {
      final sales = await _loadSales(range);
      final completedSales = sales
          .where((sale) => sale.status == 'completed')
          .toList();
      final items = await _loadSaleItems(
        completedSales.map((sale) => sale.id).toSet(),
      );
      final expenses = await _loadExpenses(range);
      final categories = await _loadExpenseCategories();
      final sessions = await _loadCashRegisterSessions(range);
      final cashPaymentMethodIds = await _loadCashPaymentMethodIds();
      final voids = await _loadSaleVoids(range);

      final grossSales = completedSales.fold(
        0,
        (total, sale) => total + sale.totalInCents,
      );
      final grossProfit = items.fold(
        0,
        (total, item) => total + item.totalInCents - item.totalCostInCents,
      );
      final expensesTotal = expenses.fold(
        0,
        (total, expense) => total + expense.amountInCents,
      );
      final averageTicket = completedSales.isEmpty
          ? 0
          : grossSales ~/ completedSales.length;
      final productRanking = _rankProducts(items);

      final expensesBySession = <String, int>{};
      for (final expense in expenses) {
        final sessionId = expense.cashRegisterSessionId;
        if (sessionId == null) continue;
        expensesBySession[sessionId] =
            (expensesBySession[sessionId] ?? 0) + expense.amountInCents;
      }

      final cashSalesBySession = <String, int>{};
      for (final sale in completedSales) {
        final sessionId = sale.cashRegisterSessionId;
        if (sessionId == null) continue;
        if (!cashPaymentMethodIds.contains(sale.paymentMethodId)) continue;
        cashSalesBySession[sessionId] =
            (cashSalesBySession[sessionId] ?? 0) + sale.totalInCents;
      }

      var cashOpening = 0;
      var cashSales = 0;
      var cashExpenses = 0;
      var cashExpected = 0;
      var cashPhysical = 0;
      var cashDifference = 0;

      for (final session in sessions) {
        final sessionCashSales = cashSalesBySession[session.id] ?? 0;
        final sessionExpenses = expensesBySession[session.id] ?? 0;
        final expected =
            session.openingCashInCents + sessionCashSales - sessionExpenses;
        final physical = session.physicalClosingCashInCents ?? 0;

        cashOpening += session.openingCashInCents;
        cashSales += sessionCashSales;
        cashExpenses += sessionExpenses;
        cashExpected += expected;
        cashPhysical += physical;
        if (session.physicalClosingCashInCents != null) {
          cashDifference += physical - expected;
        }
      }

      return AppSuccess(
        ReportSummary(
          from: range.from,
          to: range.to,
          cashDifferenceInCents: cashDifference,
          cashExpectedInCents: cashExpected,
          cashExpensesInCents: cashExpenses,
          cashOpeningInCents: cashOpening,
          cashPhysicalInCents: cashPhysical,
          cashSalesInCents: cashSales,
          cashSessionsCount: sessions.length,
          salesCount: completedSales.length,
          voidsCount: voids.length,
          grossSalesInCents: grossSales,
          grossProfitInCents: grossProfit,
          expensesInCents: expensesTotal,
          expenses: _expenseDetails(expenses, categories),
          netProfitInCents: grossProfit - expensesTotal,
          averageTicketInCents: averageTicket,
          topProducts: productRanking,
          lowestProducts: productRanking.reversed.toList(),
          voids: voids,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_reports_failed',
          message: 'No se pudieron consultar los reportes en Supabase.',
          cause: error,
        ),
      );
    }
  }

  Future<List<_RemoteSale>> _loadSales(ReportDateRange range) async {
    final rows = await _getRows('sales', {
      'select':
          'id,invoice_number,table_id,table_account_id,'
          'cash_register_session_id,payment_method_id,payment_reference,'
          'status,sync_status,total_amount,sold_at',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'and': _dateRangeFilter('sold_at', range.from, range.to),
      'order': 'sold_at.desc',
    });

    return rows.map((row) {
      return _RemoteSale(
        id: _requiredText(row, 'id'),
        invoiceNumber: _requiredText(row, 'invoice_number'),
        tableId: _optionalText(row['table_id']),
        tableAccountId: _optionalText(row['table_account_id']),
        cashRegisterSessionId: _optionalText(row['cash_register_session_id']),
        paymentMethodId: _requiredText(row, 'payment_method_id'),
        paymentReference: _optionalText(row['payment_reference']),
        status: row['status']?.toString() ?? 'completed',
        syncStatus: row['sync_status']?.toString() ?? 'synced',
        totalInCents: _moneyToCents(row['total_amount']),
        createdAt: _dateTime(row['sold_at']),
      );
    }).toList();
  }

  Future<List<_RemoteSaleItem>> _loadSaleItems(Set<String> saleIds) async {
    if (saleIds.isEmpty) return const [];

    final rows = await _getRows('sale_items', {
      'select':
          'id,sale_id,product_id,product_code,table_account_id,'
          'product_name,category_name,selected_options_label,quantity,'
          'unit_price,unit_cost,created_at',
      'sale_id': _inFilter(saleIds),
      'order': 'created_at.asc',
    });

    return rows.map((row) {
      final quantity = _quantity(row['quantity']);
      final unitPrice = _moneyToCents(row['unit_price']);
      final unitCost = _moneyToCents(row['unit_cost']);
      return _RemoteSaleItem(
        id: _requiredText(row, 'id'),
        saleId: _requiredText(row, 'sale_id'),
        tableAccountId: _optionalText(row['table_account_id']),
        productId:
            _optionalText(row['product_id']) ??
            _optionalText(row['product_code']) ??
            _requiredText(row, 'id'),
        productName: _requiredText(row, 'product_name'),
        categoryName: _requiredText(row, 'category_name'),
        selectedOptionsLabel: _optionalText(row['selected_options_label']),
        quantity: quantity,
        unitPriceInCents: unitPrice,
        unitCostInCents: unitCost,
        totalInCents: quantity * unitPrice,
        totalCostInCents: quantity * unitCost,
        createdAt: _dateTime(row['created_at']),
      );
    }).toList();
  }

  Future<List<_RemoteExpense>> _loadExpenses(ReportDateRange range) async {
    final rows = await _getRows('operating_expenses', {
      'select':
          'id,expense_category_id,cash_register_session_id,'
          'created_by_user_id,description,amount,spent_at',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'and': _dateRangeFilter('spent_at', range.from, range.to),
      'order': 'spent_at.desc',
    });

    return rows.map((row) {
      return _RemoteExpense(
        id: _requiredText(row, 'id'),
        categoryId: _requiredText(row, 'expense_category_id'),
        cashRegisterSessionId: _optionalText(row['cash_register_session_id']),
        amountInCents: _moneyToCents(row['amount']),
        description: _requiredText(row, 'description'),
        createdBy: _optionalText(row['created_by_user_id']) ?? 'Remoto',
        createdAt: _dateTime(row['spent_at']),
      );
    }).toList();
  }

  Future<Map<String, String>> _loadExpenseCategories() async {
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

  Future<List<_RemoteCashSession>> _loadCashRegisterSessions(
    ReportDateRange range,
  ) async {
    final rows = await _getRows('cash_register_sessions', {
      'select':
          'id,cashier_user_id,business_date,opening_cash_amount,'
          'counted_cash_amount,status',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'and':
          '(business_date.gte.${BusinessDateFormatter.format(range.from)},'
          'business_date.lt.${BusinessDateFormatter.format(range.to)})',
      'order': 'business_date.asc',
    });

    return rows.map((row) {
      return _RemoteCashSession(
        id: _requiredText(row, 'id'),
        cashierId: _requiredText(row, 'cashier_user_id'),
        businessDate: DateTime.parse(_requiredText(row, 'business_date')),
        openingCashInCents: _moneyToCents(row['opening_cash_amount']),
        physicalClosingCashInCents: row['counted_cash_amount'] == null
            ? null
            : _moneyToCents(row['counted_cash_amount']),
        status: row['status']?.toString() ?? 'open',
      );
    }).toList();
  }

  Future<Set<String>> _loadCashPaymentMethodIds() async {
    final restaurantFilter =
        '(restaurant_id.eq.${_restaurantService.restaurantId},'
        'restaurant_id.is.null)';
    final rows = await _getRows('payment_methods', {
      'select': 'id,affects_cash',
      'or': restaurantFilter,
    });

    return rows
        .where((row) => row['affects_cash'] == true)
        .map((row) => _requiredText(row, 'id'))
        .toSet();
  }

  Future<List<SaleVoid>> _loadSaleVoids(ReportDateRange range) async {
    final rows = await _getRows('sale_voids', {
      'select': 'id,sale_id,reason,voided_by_user_id,voided_at',
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'and': _dateRangeFilter('voided_at', range.from, range.to),
      'order': 'voided_at.desc',
    });

    return rows.map((row) {
      return SaleVoid(
        id: _requiredText(row, 'id'),
        saleId: _requiredText(row, 'sale_id'),
        reason: _requiredText(row, 'reason'),
        voidedBy: _optionalText(row['voided_by_user_id']) ?? 'Remoto',
        voidedAt: _dateTime(row['voided_at']),
      );
    }).toList();
  }

  List<ExpenseReportEntry> _expenseDetails(
    List<_RemoteExpense> expenses,
    Map<String, String> categories,
  ) {
    return expenses.map((expense) {
      return ExpenseReportEntry(
        id: expense.id,
        categoryId: expense.categoryId,
        categoryName: categories[expense.categoryId] ?? 'Sin categoria',
        amountInCents: expense.amountInCents,
        description: expense.description,
        createdAt: expense.createdAt,
        createdBy: expense.createdBy,
      );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ProductSalesMetric> _rankProducts(List<_RemoteSaleItem> items) {
    final metrics = <String, ProductSalesMetric>{};

    for (final item in items) {
      final current = metrics[item.productId];
      metrics[item.productId] = ProductSalesMetric(
        productId: item.productId,
        productName: item.productName,
        quantity: (current?.quantity ?? 0) + item.quantity,
        salesInCents: (current?.salesInCents ?? 0) + item.totalInCents,
        profitInCents:
            (current?.profitInCents ?? 0) +
            item.totalInCents -
            item.totalCostInCents,
      );
    }

    return metrics.values.toList()..sort((a, b) {
      final quantityComparison = b.quantity.compareTo(a.quantity);
      if (quantityComparison != 0) return quantityComparison;
      return b.salesInCents.compareTo(a.salesInCents);
    });
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> queryParameters,
  ) async {
    final response = await _client.get(
      _config.restUri(table, queryParameters),
      headers: await _headers(),
    );
    _ensureSuccess(response, table);

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Future<Map<String, String>> _headers() async {
    return {
      'apikey': _config.publishableKey,
      'Authorization': 'Bearer ${await _token()}',
      'Content-Type': 'application/json',
    };
  }

  Future<String> _token() async {
    final currentToken = _accessToken;
    final expiration = _expiresAt;
    final now = DateTime.now();
    if (currentToken != null &&
        expiration != null &&
        expiration.isAfter(now.add(const Duration(minutes: 1)))) {
      return currentToken;
    }

    final response = await _client.post(
      _config.passwordGrantUri,
      headers: {
        'apikey': _config.publishableKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': _config.authEmail,
        'password': _config.authPassword,
      }),
    );
    _ensureSuccess(response, 'auth');

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Supabase auth response is invalid.');
    }

    final token = decoded['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('Supabase auth response did not include a token.');
    }

    final expiresIn = decoded['expires_in'] is num
        ? (decoded['expires_in'] as num).toInt()
        : 3600;
    _accessToken = token;
    _expiresAt = now.add(Duration(seconds: expiresIn));
    return token;
  }

  void _ensureSuccess(http.Response response, String table) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    throw StateError(
      'Supabase rechazo consulta de reportes en $table '
      '(${response.statusCode}): ${response.body}',
    );
  }

  String _dateRangeFilter(String column, DateTime from, DateTime to) {
    return '($column.gte.${from.toUtc().toIso8601String()},'
        '$column.lt.${to.toUtc().toIso8601String()})';
  }

  String _inFilter(Set<String> values) {
    return 'in.(${values.join(',')})';
  }

  String _requiredText(Map<String, Object?> row, String key) {
    final value = _optionalText(row[key]);
    if (value == null) throw StateError('Missing required field $key.');
    return value;
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
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

  int _quantity(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.round();
    return (num.tryParse(value.toString()) ?? 0).round();
  }
}

final class _RemoteSale {
  const _RemoteSale({
    required this.id,
    required this.invoiceNumber,
    required this.paymentMethodId,
    required this.status,
    required this.syncStatus,
    required this.totalInCents,
    required this.createdAt,
    this.tableId,
    this.tableAccountId,
    this.cashRegisterSessionId,
    this.paymentReference,
  });

  final String id;
  final String invoiceNumber;
  final String? tableId;
  final String? tableAccountId;
  final String? cashRegisterSessionId;
  final String paymentMethodId;
  final String? paymentReference;
  final String status;
  final String syncStatus;
  final int totalInCents;
  final DateTime createdAt;
}

final class _RemoteSaleItem {
  const _RemoteSaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.categoryName,
    required this.quantity,
    required this.unitPriceInCents,
    required this.unitCostInCents,
    required this.totalInCents,
    required this.totalCostInCents,
    required this.createdAt,
    this.tableAccountId,
    this.selectedOptionsLabel,
  });

  final String id;
  final String saleId;
  final String? tableAccountId;
  final String productId;
  final String productName;
  final String categoryName;
  final String? selectedOptionsLabel;
  final int quantity;
  final int unitPriceInCents;
  final int unitCostInCents;
  final int totalInCents;
  final int totalCostInCents;
  final DateTime createdAt;
}

final class _RemoteExpense {
  const _RemoteExpense({
    required this.id,
    required this.categoryId,
    required this.amountInCents,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.cashRegisterSessionId,
  });

  final String id;
  final String categoryId;
  final String? cashRegisterSessionId;
  final int amountInCents;
  final String description;
  final String createdBy;
  final DateTime createdAt;
}

final class _RemoteCashSession {
  const _RemoteCashSession({
    required this.id,
    required this.cashierId,
    required this.businessDate,
    required this.openingCashInCents,
    required this.status,
    this.physicalClosingCashInCents,
  });

  final String id;
  final String cashierId;
  final DateTime businessDate;
  final int openingCashInCents;
  final int? physicalClosingCashInCents;
  final String status;
}
