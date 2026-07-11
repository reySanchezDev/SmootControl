part of 'supabase_report_summary_service.dart';

extension _SupabaseReportSummaryQueries on SupabaseReportSummaryService {
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
}
