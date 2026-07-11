part of 'supabase_sync_remote_sender.dart';

extension on SupabaseSyncRemoteSender {
  Future<void> _pushSale(SyncQueueItem item) async {
    final salePayload = _mapPayload(item.payload['sale']);
    if (_optionalText(salePayload['saleKind']) == 'staff_consumption') {
      await _pushStaffConsumptionWithDevice(item);
      return;
    }

    if (await _hasDeviceCredentials()) {
      await _pushSaleWithDevice(item);
      return;
    }

    if (!_remoteSessionService.hasUsableToken) {
      await _pushSaleWithDevice(item);
      return;
    }

    final itemPayloads = _listPayload(item.payload['items']);
    final remoteUserId = await _authUserId();
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
    );

    await _upsert('sales', {
      'id': saleId,
      'local_id': salePayload['id'],
      'restaurant_id': _restaurantId,
      'cash_register_session_id': cashRegisterSessionId,
      'table_id': salePayload['tableId'],
      'table_account_id': tableAccountId,
      'account_name': salePayload['tableAccountId'],
      'user_id': remoteUserId,
      'payment_method_id': salePayload['paymentMethodId'],
      'sales_type_id': salePayload['salesTypeId'],
      'sales_type_name': salePayload['salesTypeName'],
      'payment_reference': salePayload['paymentReference'],
      'invoice_number': salePayload['invoiceNumber'],
      'sale_kind': salePayload['saleKind'] ?? 'sale',
      'employee_id': salePayload['employeeId'],
      'internal_receipt_number': salePayload['internalReceiptNumber'],
      'payroll_run_id': salePayload['payrollRunId'],
      'total_amount': _money(totalAmount),
      'total_cost': _money(totalCost),
      'gross_profit': _money(totalAmount - totalCost),
      'status': salePayload['status'],
      'sync_status': 'synced',
      'sold_at': salePayload['createdAt'],
      'updated_at': DateTime.now().toIso8601String(),
    });

    for (final saleItem in itemPayloads) {
      await _upsert('sale_items', _saleItemPayload(saleItem, saleId));
    }

    for (final movement in _listPayload(item.payload['inventoryMovements'])) {
      await _applyInventoryMovement(movement);
    }
    for (final movement in _listPayload(item.payload['packagingMovements'])) {
      await _applyPackagingMovement(movement);
    }

    final voidPayload = _mapPayload(item.payload['void']);
    if (voidPayload.isNotEmpty) {
      await _upsert(
        'sale_voids',
        {
          'sale_id': saleId,
          'restaurant_id': _restaurantId,
          'cash_register_session_id': cashRegisterSessionId,
          'voided_by_user_id': remoteUserId,
          'reason': voidPayload['reason'] ?? 'Anulacion local',
          'original_total_amount': _money(totalAmount),
          'original_payment_method_id': salePayload['paymentMethodId'],
          'original_payment_reference': salePayload['paymentReference'],
          'sync_status': 'synced',
        },
        conflictColumn: 'sale_id',
      );
    }
  }

  Map<String, Object?> _saleItemPayload(
    Map<String, Object?> payload,
    String saleId,
  ) {
    final quantity = _intValue(payload['quantity']);
    final unitPrice = _intValue(payload['unitPriceInCents']);
    final unitCost = _intValue(payload['unitCostInCents']);
    final subtotal = quantity * unitPrice;
    final totalCost = quantity * unitCost;
    return {
      'id': _remoteUuid(payload['id'], scope: 'sale_items'),
      'sale_id': saleId,
      'product_id': payload['productId'],
      'table_account_id': _nullableRemoteUuid(
        payload['tableAccountId'],
        scope: 'table_accounts',
      ),
      'product_code': payload['productId'],
      'product_name': payload['productName'],
      'category_name': payload['categoryName'],
      'selected_options_label': payload['selectedOptionsLabel'],
      'quantity': quantity,
      'unit_price': _money(unitPrice),
      'unit_cost': _money(unitCost),
      'subtotal': _money(subtotal),
      'gross_profit': _money(subtotal - totalCost),
      'created_at': payload['createdAt'],
    };
  }
}
