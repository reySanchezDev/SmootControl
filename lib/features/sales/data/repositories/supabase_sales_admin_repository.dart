import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:uuid/uuid.dart';

/// Administrative sales repository backed directly by Supabase.
///
/// POS keeps using the local offline repository. This repository is for
/// backoffice screens, where Supabase is the source of truth.
final class SupabaseSalesAdminRepository implements ISalesRepository {
  /// Creates a Supabase-backed sales repository.
  const SupabaseSalesAdminRepository({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
    Uuid uuid = const Uuid(),
  }) : _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client,
       _uuid = uuid;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;
  final Uuid _uuid;

  @override
  Future<AppResult<List<Sale>>> getSales({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _getRows('sales', {
        'select':
            'id,invoice_number,table_id,table_account_id,'
            'cash_register_session_id,payment_method_id,payment_reference,'
            'sales_type_id,sales_type_name,status,sync_status,total_amount,'
            'sold_at,created_at',
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'and': _dateRangeFilter('sold_at', from, to),
        'order': 'sold_at.desc',
      });

      return AppSuccess(rows.map(_saleFromRow).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_sales_read_failed',
          message: 'No se pudieron consultar las ventas en Supabase.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<Sale>>> getSalesByCashRegisterSession(
    String sessionId,
  ) async {
    try {
      final rows = await _getRows('sales', {
        'select':
            'id,invoice_number,table_id,table_account_id,'
            'cash_register_session_id,payment_method_id,payment_reference,'
            'sales_type_id,sales_type_name,status,sync_status,total_amount,'
            'sold_at,created_at',
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'cash_register_session_id': 'eq.$sessionId',
        'order': 'sold_at.desc',
      });

      return AppSuccess(rows.map(_saleFromRow).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_sales_by_cash_read_failed',
          message: 'No se pudieron consultar las ventas de caja en Supabase.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<SaleItem>>> getSaleItems(String saleId) async {
    try {
      final rows = await _getRows('sale_items', {
        'select':
            'id,sale_id,table_account_id,product_id,product_code,'
            'product_name,category_name,selected_options_label,quantity,'
            'unit_price,unit_cost,created_at',
        'sale_id': 'eq.$saleId',
        'order': 'created_at.asc',
      });

      return AppSuccess(rows.map(_saleItemFromRow).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_sale_items_read_failed',
          message: 'No se pudo consultar el detalle de la venta en Supabase.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<SaleVoid>>> getSaleVoids({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _getRows('sale_voids', {
        'select': 'id,sale_id,reason,voided_by_user_id,voided_at',
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'and': _dateRangeFilter('voided_at', from, to),
        'order': 'voided_at.desc',
      });

      return AppSuccess(rows.map(_saleVoidFromRow).toList());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_sale_voids_read_failed',
          message: 'No se pudieron consultar anulaciones en Supabase.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<AppResult<Sale>> saveSale({
    required Sale sale,
    required List<SaleItem> items,
  }) async {
    return const AppFailureResult(
      AppFailure(
        code: 'remote_sales_save_not_supported',
        message: 'Las ventas se registran desde el POS.',
      ),
    );
  }

  @override
  Future<AppResult<Sale>> voidSale({
    required String saleId,
    required String reason,
    required String voidedBy,
  }) async {
    try {
      final saleRows = await _getRows('sales', {
        'select':
            'id,invoice_number,table_id,table_account_id,'
            'cash_register_session_id,payment_method_id,payment_reference,'
            'sales_type_id,sales_type_name,status,sync_status,total_amount,'
            'sold_at,created_at',
        'id': 'eq.$saleId',
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'limit': '1',
      });
      if (saleRows.isEmpty) {
        throw StateError('Venta no encontrada en Supabase.');
      }

      await _patchRows(
        'sales',
        {'status': 'voided', 'updated_at': DateTime.now().toIso8601String()},
        {'id': 'eq.$saleId'},
      );
      await _insertRow('sale_voids', {
        'id': _uuid.v4(),
        'restaurant_id': _restaurantService.restaurantId,
        'sale_id': saleId,
        'reason': reason,
        'voided_by_user_id': _remoteSessionService.userId ?? voidedBy,
        'voided_at': DateTime.now().toUtc().toIso8601String(),
      });

      return AppSuccess(_saleFromRow({...saleRows.single, 'status': 'voided'}));
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'remote_sale_void_failed',
          message: 'No se pudo anular la venta en Supabase.',
          cause: error,
        ),
      );
    }
  }

  Sale _saleFromRow(Map<String, Object?> row) {
    return Sale(
      id: _requiredText(row, 'id'),
      invoiceNumber: _requiredText(row, 'invoice_number'),
      tableId: _optionalText(row['table_id']),
      tableAccountId: _optionalText(row['table_account_id']),
      cashRegisterSessionId: _optionalText(row['cash_register_session_id']),
      paymentMethodId: _requiredText(row, 'payment_method_id'),
      salesTypeId: _optionalText(row['sales_type_id']),
      salesTypeName: _optionalText(row['sales_type_name']),
      paymentReference: _optionalText(row['payment_reference']),
      status: switch (row['status']?.toString()) {
        'voided' => SaleStatus.voided,
        _ => SaleStatus.completed,
      },
      syncStatus: switch (row['sync_status']?.toString()) {
        'pending' => SaleSyncStatus.pending,
        'syncing' => SaleSyncStatus.syncing,
        'error' => SaleSyncStatus.error,
        _ => SaleSyncStatus.synced,
      },
      subtotalInCents: _moneyToCents(row['total_amount']),
      totalInCents: _moneyToCents(row['total_amount']),
      createdAt: _dateTime(row['sold_at'] ?? row['created_at']),
    );
  }

  SaleItem _saleItemFromRow(Map<String, Object?> row) {
    return SaleItem(
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
      quantity: _quantity(row['quantity']),
      unitPriceInCents: _moneyToCents(row['unit_price']),
      unitCostInCents: _moneyToCents(row['unit_cost']),
      createdAt: _dateTime(row['created_at']),
    );
  }

  SaleVoid _saleVoidFromRow(Map<String, Object?> row) {
    return SaleVoid(
      id: _requiredText(row, 'id'),
      saleId: _requiredText(row, 'sale_id'),
      reason: _requiredText(row, 'reason'),
      voidedBy: _optionalText(row['voided_by_user_id']) ?? '',
      voidedAt: _dateTime(row['voided_at']),
    );
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

  Future<void> _patchRows(
    String table,
    Map<String, Object?> body,
    Map<String, String> queryParameters,
  ) async {
    final response = await _client.patch(
      _config.restUri(table, queryParameters),
      headers: {
        ...await _headers(),
        'Prefer': 'return=minimal',
      },
      body: jsonEncode(body),
    );
    _ensureSuccess(response, table);
  }

  Future<void> _insertRow(String table, Map<String, Object?> body) async {
    final response = await _client.post(
      _config.restUri(table),
      headers: {
        ...await _headers(),
        'Prefer': 'return=minimal',
      },
      body: jsonEncode(body),
    );
    _ensureSuccess(response, table);
  }

  Future<Map<String, String>> _headers() async {
    return {
      'apikey': _config.publishableKey,
      'Authorization': 'Bearer ${await _token()}',
      'Content-Type': 'application/json',
    };
  }

  Future<String> _token() async {
    final token = _remoteSessionService.accessToken;
    if (token != null) return token;
    throw StateError(
      'La sesion remota expiro. Inicia sesion como administrador remoto.',
    );
  }

  void _ensureSuccess(http.Response response, String table) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw StateError(
      'Supabase rechazo consulta de ventas en $table '
      '(${response.statusCode}): ${response.body}',
    );
  }

  String _dateRangeFilter(String column, DateTime from, DateTime to) {
    return '($column.gte.${from.toUtc().toIso8601String()},'
        '$column.lt.${to.toUtc().toIso8601String()})';
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
