part of 'supabase_sync_remote_sender.dart';

extension on SupabaseSyncRemoteSender {
  Future<void> _pushInventoryMovement(SyncQueueItem item) async {
    await _applyInventoryMovement(item.payload);
  }

  Future<void> _pushPackagingMovement(SyncQueueItem item) async {
    await _applyPackagingMovement(item.payload);
  }

  Future<void> _pushCashRegisterSession(SyncQueueItem item) async {
    if (await _hasDeviceCredentials()) {
      await _pushCashRegisterSessionWithDevice(item);
      return;
    }

    if (!_remoteSessionService.hasUsableToken) {
      await _pushCashRegisterSessionWithDevice(item);
      return;
    }

    final payload = await _cashRegisterSessionPayload(item);
    final response = await _client.post(
      _config.restUri('cash_register_sessions', {'on_conflict': 'id'}),
      headers: await _headers(
        prefer: 'resolution=merge-duplicates,return=minimal',
      ),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final localId = _optionalText(item.payload['id']);
      if (localId != null) {
        _cashRegisterSessionAliases[localId] =
            _optionalText(payload['id']) ?? localId;
      }
      return;
    }

    if (!_isOpenCashRegisterDuplicate(response)) {
      _ensureSuccess(response, 'cash_register_sessions');
      return;
    }

    final localId = _optionalText(item.payload['id']);
    final cashierId = _optionalText(payload['cashier_user_id']);
    final businessDate = _dateOnly(payload['business_date']);
    if (localId == null || cashierId == null || businessDate == null) {
      _ensureSuccess(response, 'cash_register_sessions');
      return;
    }

    final remoteSessionId = await _findOpenCashRegisterSessionId(
      cashierId: cashierId,
      businessDate: businessDate,
    );
    if (remoteSessionId == null) {
      _ensureSuccess(response, 'cash_register_sessions');
      return;
    }
    _cashRegisterSessionAliases[localId] = remoteSessionId;
  }

  Future<void> _pushCashRegisterSessionWithDevice(SyncQueueItem item) async {
    final payload = await _cashRegisterSessionPayload(
      item,
      allowAuthFallback: false,
    );
    final result = await _deviceRpc(
      'pos_sync_cash_register_session',
      {'p_payload': payload},
    );
    final localId = _optionalText(item.payload['id']);
    final remoteId = _optionalText(result['remote_id']);
    if (localId != null && remoteId != null) {
      _cashRegisterSessionAliases[localId] = remoteId;
    }
  }

  Map<String, Object?> _deviceInventoryMovementPayload(
    Map<String, Object?> payload,
  ) {
    return {
      'id': payload['id'],
      'product_id': payload['productId'],
      'movement_type': payload['movementType'],
      'quantity_delta': _intValue(payload['quantityDelta']),
      'reference_type': payload['referenceType'],
      'reference_id': payload['referenceId'],
      'user_id': payload['userId'],
      'notes': payload['notes'],
      'created_at': payload['createdAt'],
    };
  }

  Map<String, Object?> _devicePackagingMovementPayload(
    Map<String, Object?> payload,
  ) {
    return {
      'id': payload['id'],
      'packaging_item_id': payload['packagingItemId'],
      'movement_type': payload['movementType'],
      'quantity_delta': _intValue(payload['quantityDelta']),
      'unit_cost': _money(_intValue(payload['unitCostInCents'])),
      'reference_type': payload['referenceType'],
      'reference_id': payload['referenceId'],
      'user_id': payload['userId'],
      'notes': payload['notes'],
      'created_at': payload['createdAt'],
    };
  }

  Future<String?> _cashRegisterSessionIdForSale(
    Map<String, Object?> salePayload, {
    bool allowAuthFallback = true,
  }) async {
    final localId = _optionalText(salePayload['cashRegisterSessionId']);
    return _cashRegisterSessionIdForLocalId(
      localId,
      allowAuthFallback: allowAuthFallback,
      cashierId: _optionalText(salePayload['cashierId']),
      businessDate: _dateOnly(salePayload['businessDate']),
    );
  }

  Future<String?> _cashRegisterSessionIdForLocalId(
    String? localId, {
    required bool allowAuthFallback,
    String? cashierId,
    String? businessDate,
  }) async {
    if (localId == null) return null;
    final alias = _cashRegisterSessionAliases[localId];
    if (alias != null) return alias;

    if (cashierId != null &&
        businessDate != null &&
        _remoteSessionService.hasUsableToken) {
      final remoteSessionId = await _findOpenCashRegisterSessionId(
        cashierId: cashierId,
        businessDate: businessDate,
      );
      if (remoteSessionId != null) {
        _cashRegisterSessionAliases[localId] = remoteSessionId;
        return remoteSessionId;
      }
    }

    final syncedId = await _syncLocalCashRegisterSessionById(
      localId,
      allowAuthFallback: allowAuthFallback,
    );
    return syncedId ?? localId;
  }

  Future<String?> _syncLocalCashRegisterSessionById(
    String localId, {
    required bool allowAuthFallback,
  }) async {
    final existingAlias = _cashRegisterSessionAliases[localId];
    if (existingAlias != null) return existingAlias;

    final row =
        await (_database.select(_database.localCashRegisterSessions)..where(
              (session) => session.id.equals(localId),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final item = SyncQueueItem(
      id: 'cash-register-session-inline-$localId',
      entityType: 'cash_register_sessions',
      entityId: localId,
      operation: SyncOperation.create,
      payload: {
        'id': row.id,
        'cashierId': row.cashierId,
        'businessDate': row.businessDate,
        'openingCashInCents': row.openingCashInCents,
        'physicalClosingCashInCents': row.physicalClosingCashInCents,
        'status': row.status,
      },
      status: SyncQueueStatus.pending,
      retryCount: 0,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );

    if (!allowAuthFallback || await _hasDeviceCredentials()) {
      await _pushCashRegisterSessionWithDevice(item);
    } else {
      await _pushCashRegisterSession(item);
    }

    return _cashRegisterSessionAliases[localId];
  }

  bool _isOpenCashRegisterDuplicate(http.Response response) {
    if (response.statusCode != 409) return false;
    final body = response.body;
    return body.contains('cash_register_one_open_per_user_day_idx') ||
        body.contains('duplicate key value') &&
            body.contains('cash_register_sessions');
  }
}
