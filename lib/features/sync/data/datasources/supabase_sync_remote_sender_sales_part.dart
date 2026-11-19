part of 'supabase_sync_remote_sender.dart';

extension on SupabaseSyncRemoteSender {
  Future<void> _pushSale(SyncQueueItem item) async {
    final salePayload = _mapPayload(item.payload['sale']);
    if (_optionalText(salePayload['saleKind']) == 'staff_consumption') {
      await _pushStaffConsumptionWithDevice(item);
      return;
    }

    final hasDeviceCredentials = await _hasDeviceCredentials();
    if (!hasDeviceCredentials) {
      throw StateError('pos_sale_requires_device_sync');
    }

    // A POS sale must enter through one trusted RPC so header, lines,
    // inventory, packaging and void data commit atomically on the server.
    await _pushSaleWithDevice(item);
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
      'item_id': payload['productId'],
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
