import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/reports/domain/entities/payroll_payment_receipt.dart';

/// Reads paid payroll receipts directly from Supabase.
final class SupabasePayrollReportService {
  /// Creates the service.
  const SupabasePayrollReportService({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
  }) : _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;

  /// Loads historical payroll receipts for the selected filters.
  Future<AppResult<List<PayrollPaymentReceipt>>> loadReceipts({
    required DateTime from,
    required DateTime to,
    required PayrollReceiptCut cut,
  }) async {
    try {
      final response = await _client.post(
        _config.rpcUri('app_get_paid_payroll_receipts'),
        headers: await _headers(),
        body: jsonEncode({
          'p_restaurant_id': _restaurantService.restaurantId,
          'p_from': _dateOnly(from),
          'p_to': _dateOnly(to),
          'p_cut': cut.remoteValue,
        }),
      );
      _ensureSuccess(response);
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const AppSuccess([]);
      return AppSuccess(
        decoded
            .whereType<Map<Object?, Object?>>()
            .map((row) => _receiptFromRow(row.cast<String, Object?>()))
            .toList(),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'paid_payroll_report_failed',
          message: 'No se pudieron leer las planillas pagadas.',
          cause: error,
        ),
      );
    }
  }

  /// Reverses a paid payroll receipt and revives linked pending balances.
  Future<AppResult<void>> reverseReceipt(String receiptId) async {
    try {
      final response = await _client.post(
        _config.rpcUri('app_reverse_payroll_payment_receipt'),
        headers: await _headers(),
        body: jsonEncode({
          'p_restaurant_id': _restaurantService.restaurantId,
          'p_receipt_id': receiptId,
        }),
      );
      _ensureSuccess(response);
      return const AppSuccess(null);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'paid_payroll_delete_failed',
          message: 'No se pudo eliminar el pago de planilla.',
          cause: error,
        ),
      );
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = _remoteSessionService.accessToken;
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        token == null) {
      throw StateError('Se requiere sesion remota administrativa.');
    }
    return {
      'apikey': _config.publishableKey,
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    };
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      _remoteSessionService.expire();
    }
    throw StateError('Supabase rechazo planillas pagadas: ${response.body}');
  }

  PayrollPaymentReceipt _receiptFromRow(Map<String, Object?> row) {
    final details = _map(row['details']);
    return PayrollPaymentReceipt(
      id: _text(row['id']),
      employeeId: _text(row['employee_id']),
      employeeName: _text(row['employee_name'], fallback: 'Empleado'),
      employeeCode: _text(row['employee_code']),
      positionName: _text(row['position_name']),
      periodStart: _date(row['period_start']),
      periodEnd: _date(row['period_end']),
      periodLabel: _text(row['period_label'], fallback: 'Planilla'),
      baseSalaryInCents: _moneyToCents(row['base_salary']),
      overtimeInCents: _moneyToCents(row['overtime_amount']),
      consumptionInCents: _moneyToCents(row['staff_consumption_amount']),
      advanceDeductionInCents: _moneyToCents(
        row['salary_advance_deduction'],
      ),
      netPayInCents: _moneyToCents(row['net_pay']),
      paymentAmountInCents: _moneyToCents(row['payment_amount']),
      paidAmountAfterInCents: _moneyToCents(row['line_paid_amount_after']),
      balanceAfterInCents: _moneyToCents(row['line_balance_amount_after']),
      advanceBalanceAfterInCents: _moneyToCents(
        row['advance_balance_after'],
      ),
      consumptions: _consumptions(details['consumptions']),
      overtimeEntries: _overtime(details['overtime_entries']),
      advances: _advances(details['salary_advances']),
      paidAt: _date(row['paid_at']),
    );
  }

  List<PayrollReceiptOvertime> _overtime(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map<Object?, Object?>>().map((row) {
      final map = row.cast<String, Object?>();
      return PayrollReceiptOvertime(
        date: _date(map['date']),
        hours: double.tryParse(_text(map['hours'])) ?? 0,
        hourRateInCents: _moneyToCents(map['hour_rate']),
        amountInCents: _moneyToCents(map['amount']),
        note: _text(map['note']),
      );
    }).toList();
  }

  List<PayrollReceiptConsumption> _consumptions(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map<Object?, Object?>>().map((row) {
      final map = row.cast<String, Object?>();
      return PayrollReceiptConsumption(
        receipt: _text(map['receipt'], fallback: 'Consumo'),
        date: _date(map['date']),
        amountInCents: _moneyToCents(map['amount']),
      );
    }).toList();
  }

  List<PayrollReceiptAdvance> _advances(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map<Object?, Object?>>().map((row) {
      final map = row.cast<String, Object?>();
      return PayrollReceiptAdvance(
        deliveredAt: _date(map['delivered_at']),
        originalAmountInCents: _moneyToCents(map['original_amount']),
        appliedAmountInCents: _moneyToCents(map['applied_amount']),
        balanceAfterInCents: _moneyToCents(map['balance_after']),
      );
    }).toList();
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<Object?, Object?>) return value.cast<String, Object?>();
    return const {};
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  DateTime _date(Object? value) =>
      DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();

  int _moneyToCents(Object? value) {
    if (value is int) return value * 100;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value?.toString() ?? '') ?? 0) * 100).round();
  }

  String _dateOnly(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

/// Payroll report cut filter.
enum PayrollReceiptCut {
  /// Every period in the selected date range.
  all('all', 'Todos'),

  /// First half of month.
  first('first', 'Primera quincena'),

  /// Second half of month.
  second('second', 'Segunda quincena')
  ;

  const PayrollReceiptCut(this.remoteValue, this.label);

  /// RPC filter value.
  final String remoteValue;

  /// User-facing label.
  final String label;
}
