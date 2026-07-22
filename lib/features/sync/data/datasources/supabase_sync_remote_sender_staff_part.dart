part of 'supabase_sync_remote_sender.dart';

extension on SupabaseSyncRemoteSender {
  Future<void> _pushEmployeeAttendanceEntry(SyncQueueItem item) async {
    final payload = item.payload;
    await _deviceRpc('pos_sync_employee_attendance_entry', {
      'p_payload': {
        'id': _remoteUuid(payload['id'], scope: 'employee_attendance_entries'),
        'local_id': payload['id'],
        'employee_id': payload['employeeId'],
        'work_date': payload['workDate'],
        'clock_in_at': payload['clockInAt'],
        'clock_out_at': payload['clockOutAt'],
        'status': payload['status'],
        'source': payload['source'] ?? 'time_clock',
        'verification_method': payload['verificationMethod'] ?? 'photo_tap',
        'note': payload['note'],
        'created_at': payload['createdAt'],
      },
    });
  }

  Future<void> _pushSaleWithDevice(SyncQueueItem item) async {
    final salePayload = _mapPayload(item.payload['sale']);
    final itemPayloads = _listPayload(item.payload['items']);
    final cashierId =
        _optionalText(salePayload['cashierId']) ?? await _deviceUserId();
    final totalCost = itemPayloads.fold<int>(
      0,
      (total, saleItem) {
        final quantity = _intValue(saleItem['quantity']);
        final cost = _intValue(saleItem['unitCostInCents']);
        return total + (quantity * cost);
      },
    );
    final totalAmount = _intValue(salePayload['totalInCents']);
    final saleId = _remoteUuid(salePayload['id'], scope: 'sales');
    final tableAccountId = _nullableRemoteUuid(
      salePayload['tableAccountId'],
      scope: 'table_accounts',
    );
    final cashRegisterSessionId = await _cashRegisterSessionIdForSale(
      salePayload,
      allowAuthFallback: false,
    );

    final result = await _deviceRpc('pos_sync_sale', {
      'p_payload': {
        'sale': {
          'id': saleId,
          'local_id': salePayload['id'],
          'cash_register_session_id': cashRegisterSessionId,
          'business_date': _dateOnly(salePayload['businessDate']),
          'table_id': salePayload['tableId'],
          'table_account_id': tableAccountId,
          'account_name': salePayload['tableAccountId'],
          'user_id': cashierId,
          'payment_method_id': salePayload['paymentMethodId'],
          'sales_type_id': salePayload['salesTypeId'],
          'sales_type_name': salePayload['salesTypeName'],
          'payment_reference': salePayload['paymentReference'],
          'payment_currency_code': salePayload['paymentCurrencyCode'],
          'exchange_rate': _optionalMoney(salePayload['exchangeRateInCents']),
          'invoice_number': salePayload['invoiceNumber'],
          'sale_kind': salePayload['saleKind'] ?? 'sale',
          'employee_id': salePayload['employeeId'],
          'internal_receipt_number': salePayload['internalReceiptNumber'],
          'payroll_run_id': salePayload['payrollRunId'],
          'total_amount': _money(totalAmount),
          'total_cost': _money(totalCost),
          'gross_profit': _money(totalAmount - totalCost),
          'status': salePayload['status'],
          'sold_at': salePayload['createdAt'],
        },
        'items': itemPayloads.map((payload) {
          return _saleItemPayload(payload, saleId);
        }).toList(),
        'inventory_movements': _listPayload(
          item.payload['inventoryMovements'],
        ).map(_deviceInventoryMovementPayload).toList(),
        'packaging_movements': _listPayload(
          item.payload['packagingMovements'],
        ).map(_devicePackagingMovementPayload).toList(),
        'void': _mapPayload(item.payload['void']),
      },
    });
    await _applyRemoteSaleResult(
      result: result,
      salePayload: salePayload,
    );
  }

  Future<void> _pushStaffConsumptionWithDevice(SyncQueueItem item) async {
    final salePayload = _mapPayload(item.payload['sale']);
    final itemPayloads = _listPayload(item.payload['items']);
    final cashierId =
        _optionalText(salePayload['cashierId']) ?? await _deviceUserId();
    final totalCost = itemPayloads.fold<int>(
      0,
      (total, saleItem) {
        final quantity = _intValue(saleItem['quantity']);
        final cost = _intValue(saleItem['unitCostInCents']);
        return total + (quantity * cost);
      },
    );
    final totalAmount = _intValue(salePayload['totalInCents']);
    final saleId = _remoteUuid(salePayload['id'], scope: 'sales');
    final cashRegisterSessionId = await _cashRegisterSessionIdForSale(
      salePayload,
      allowAuthFallback: false,
    );

    final result = await _deviceRpc('pos_sync_staff_consumption', {
      'p_payload': {
        'sale': {
          'id': saleId,
          'local_id': salePayload['id'],
          'cash_register_session_id': cashRegisterSessionId,
          'business_date': _dateOnly(salePayload['businessDate']),
          'table_id': salePayload['tableId'],
          'table_account_id': salePayload['tableAccountId'],
          'account_name': salePayload['tableAccountId'],
          'user_id': cashierId,
          'payment_method_id': salePayload['paymentMethodId'],
          'sales_type_id': salePayload['salesTypeId'],
          'sales_type_name': salePayload['salesTypeName'],
          'payment_reference': salePayload['paymentReference'],
          'payment_currency_code': salePayload['paymentCurrencyCode'],
          'exchange_rate': _optionalMoney(salePayload['exchangeRateInCents']),
          'invoice_number': salePayload['invoiceNumber'],
          'sale_kind': 'staff_consumption',
          'employee_id': salePayload['employeeId'],
          'internal_receipt_number': salePayload['internalReceiptNumber'],
          'total_amount': _money(totalAmount),
          'total_cost': _money(totalCost),
          'gross_profit': _money(totalAmount - totalCost),
          'status': salePayload['status'],
          'sold_at': salePayload['createdAt'],
        },
        'items': itemPayloads.map((payload) {
          return _saleItemPayload(payload, saleId);
        }).toList(),
        'inventory_movements': _listPayload(
          item.payload['inventoryMovements'],
        ).map(_deviceInventoryMovementPayload).toList(),
        'packaging_movements': _listPayload(
          item.payload['packagingMovements'],
        ).map(_devicePackagingMovementPayload).toList(),
      },
    });
    await _applyRemoteSaleResult(
      result: result,
      salePayload: salePayload,
      updateInvoiceSettings: false,
    );
  }

  Future<void> _pushSalaryAdvance(SyncQueueItem item) async {
    final payload = item.payload;
    final cashRegisterSessionId = await _cashRegisterSessionIdForLocalId(
      _optionalText(payload['cashRegisterSessionId']),
      allowAuthFallback: false,
    );
    final createdBy =
        _optionalText(payload['createdBy']) ?? await _deviceUserId();

    await _deviceRpc('pos_sync_salary_advance', {
      'p_payload': {
        'id': _remoteUuid(payload['id'], scope: 'salary_advances'),
        'local_id': payload['id'],
        'employee_id': payload['employeeId'],
        'cash_register_session_id': cashRegisterSessionId,
        'amount': _money(_intValue(payload['amountInCents'])),
        'affects_cash': payload['affectsCash'] == true,
        'note': payload['note'],
        'created_by_user_id': createdBy,
        'created_at': payload['createdAt'],
        'delivered_at': payload['deliveredAt'] ?? payload['createdAt'],
      },
    });
  }

  Future<void> _pushOperatingExpenseWithDevice(SyncQueueItem item) async {
    final payload = item.payload;
    final cashRegisterSessionId = await _cashRegisterSessionIdForLocalId(
      _optionalText(payload['cashRegisterSessionId']),
      allowAuthFallback: false,
    );
    final createdBy =
        _optionalText(payload['createdBy']) ?? await _deviceUserId();

    await _deviceRpc('pos_sync_operating_expense', {
      'p_payload': {
        'id': _remoteUuid(payload['id'], scope: 'operating_expenses'),
        'local_id': payload['id'],
        'expense_category_id': payload['categoryId'],
        'cash_register_session_id': cashRegisterSessionId,
        'created_by_user_id': createdBy,
        'description': payload['description'],
        'amount': _money(_intValue(payload['amountInCents'])),
        'expense_kind': payload['expenseKind'] ?? 'operational',
        'employee_id': payload['employeeId'],
        'affects_cash': payload['affectsCash'] != false,
        'spent_at': payload['createdAt'],
      },
    });
  }

  Future<void> _pushTableAccountWithDevice(SyncQueueItem item) async {
    final payload = item.payload;
    await _deviceRpc('pos_sync_table_account', {
      'p_payload': {
        'id': _remoteUuid(payload['id'], scope: 'table_accounts'),
        'table_id': payload['table_id'],
        'name': payload['name'],
        'status': payload['status'],
        'created_by_user_id': await _deviceUserId(),
      },
    });
  }
}
