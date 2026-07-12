part of 'supabase_sales_admin_repository.dart';

extension _SupabaseSalesAdminRepositorySupport on SupabaseSalesAdminRepository {
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
