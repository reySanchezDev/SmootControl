part of 'supabase_sync_remote_sender.dart';

extension on SupabaseSyncRemoteSender {
  Future<void> _upsert(
    String table,
    Map<String, Object?> payload, {
    String conflictColumn = 'id',
  }) async {
    final response = await _client.post(
      _config.restUri(table, {'on_conflict': conflictColumn}),
      headers: await _headers(
        prefer: 'resolution=merge-duplicates,return=minimal',
      ),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, table);
  }

  Future<void> _applyInventoryMovement(Map<String, Object?> payload) async {
    if (payload.isEmpty) return;
    final response = await _client.post(
      _config.restUri('rpc/apply_inventory_movement'),
      headers: await _headers(),
      body: jsonEncode({
        'p_id': payload['id'],
        'p_restaurant_id': _restaurantId,
        'p_product_id': payload['productId'],
        'p_movement_type': payload['movementType'],
        'p_quantity_delta': _intValue(payload['quantityDelta']),
        'p_reference_type': payload['referenceType'],
        'p_reference_id': payload['referenceId'],
        'p_user_id': payload['userId'],
        'p_notes': payload['notes'],
        'p_created_at': payload['createdAt'],
        'p_unit_cost': _money(_intValue(payload['unitCostInCents'])),
      }),
    );
    _ensureSuccess(response, 'inventory_movements');
  }

  Future<void> _applyPackagingMovement(Map<String, Object?> payload) async {
    if (payload.isEmpty) return;
    final response = await _client.post(
      _config.restUri('rpc/apply_packaging_movement'),
      headers: await _headers(),
      body: jsonEncode({
        'p_id': payload['id'],
        'p_restaurant_id': _restaurantId,
        'p_packaging_item_id': payload['packagingItemId'],
        'p_movement_type': payload['movementType'],
        'p_quantity_delta': _intValue(payload['quantityDelta']),
        'p_unit_cost': _money(_intValue(payload['unitCostInCents'])),
        'p_reference_type': payload['referenceType'],
        'p_reference_id': payload['referenceId'],
        'p_user_id': payload['userId'],
        'p_notes': payload['notes'],
        'p_created_at': payload['createdAt'],
      }),
    );
    _ensureSuccess(response, 'packaging_movements');
  }

  Future<void> _deleteById(String table, String id) async {
    final response = await _client.delete(
      _config.restUri(table, {'id': 'eq.$id'}),
      headers: await _headers(prefer: 'return=minimal'),
    );
    _ensureSuccess(response, table);
  }

  Future<void> _deleteWhere(
    String table,
    Map<String, String> query,
  ) async {
    final response = await _client.delete(
      _config.restUri(table, query),
      headers: await _headers(prefer: 'return=minimal'),
    );
    _ensureSuccess(response, table);
  }

  Future<void> _patchWhere(
    String table,
    Map<String, Object?> payload,
    Map<String, String> query,
  ) async {
    final response = await _client.patch(
      _config.restUri(table, query),
      headers: await _headers(prefer: 'return=minimal'),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, table);
  }

  Future<String?> _findOpenCashRegisterSessionId({
    required String cashierId,
    required String businessDate,
  }) async {
    final rows = await _getRows('cash_register_sessions', {
      'restaurant_id': 'eq.$_restaurantId',
      'cashier_user_id': 'eq.$cashierId',
      'business_date': 'eq.$businessDate',
      'status': 'eq.open',
      'select': 'id',
      'limit': '1',
    });
    if (rows.isEmpty) return null;
    return _optionalText(rows.first['id']);
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> query,
  ) async {
    final response = await _client.get(
      _config.restUri(table, query),
      headers: await _headers(),
    );
    _ensureSuccess(response, table);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Future<Map<String, String>> _headers({String? prefer}) async {
    final headers = <String, String>{
      'apikey': _config.publishableKey,
      'authorization': 'Bearer ${await _authToken()}',
      'content-type': 'application/json',
      'accept': 'application/json',
    };
    if (prefer != null) {
      headers['prefer'] = prefer;
    }
    return headers;
  }

  Future<String> _authToken() async {
    final sessionToken = _remoteSessionService.accessToken;
    if (sessionToken != null) {
      _remoteUserId = _remoteSessionService.userId;
      return sessionToken;
    }

    throw StateError(
      'Inicia sesion como administrador remoto para sincronizar.',
    );
  }

  Future<String> _authUserId() async {
    final current = _remoteUserId;
    if (current != null && current.isNotEmpty) return current;
    await _authToken();
    final resolved = _remoteUserId;
    if (resolved == null || resolved.isEmpty) {
      throw StateError('No se pudo resolver el usuario remoto autenticado.');
    }
    return resolved;
  }

  void _ensureSuccess(http.Response response, String table) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw StateError(
      'Supabase rechazo sync en $table (${response.statusCode}): '
      '${response.body}',
    );
  }

  String get _restaurantId => _restaurantService.restaurantId;

  Future<Map<String, Object?>> _adminRpc(
    String functionName,
    Map<String, Object?> body,
  ) async {
    final response = await _client.post(
      _config.rpcUri(functionName),
      headers: await _headers(),
      body: jsonEncode({
        'p_restaurant_id': _restaurantId,
        ...body,
      }),
    );
    _ensureSuccess(response, functionName);
    if (response.body.trim().isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  Future<Map<String, Object?>> _deviceRpc(
    String functionName,
    Map<String, Object?> body,
  ) async {
    final credentials = await _deviceCredentials();
    final response = await _client.post(
      _config.rpcUri(functionName),
      headers: {
        'apikey': _config.publishableKey,
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'p_restaurant_id': _restaurantId,
        'p_device_id': credentials.deviceId,
        'p_device_secret': credentials.deviceSecret,
        ...body,
      }),
    );
    _ensureSuccess(response, functionName);
    if (response.body.trim().isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  Future<_DeviceSyncCredentials> _deviceCredentials() async {
    final state = await (_database.select(
      _database.localDeviceState,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
    final deviceId = _optionalText(state?.syncDeviceId ?? state?.deviceId);
    final deviceSecret = _optionalText(state?.syncDeviceSecret);
    if (deviceId == null || deviceSecret == null) {
      throw StateError(
        'Este dispositivo no tiene credencial de sincronizacion POS. '
        'Inicializa la tableta desde Supabase nuevamente.',
      );
    }
    return _DeviceSyncCredentials(
      deviceId: deviceId,
      deviceSecret: deviceSecret,
    );
  }

  Future<bool> _hasDeviceCredentials() async {
    final state = await (_database.select(
      _database.localDeviceState,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
    final deviceId = _optionalText(state?.syncDeviceId ?? state?.deviceId);
    final deviceSecret = _optionalText(state?.syncDeviceSecret);
    return deviceId != null && deviceSecret != null;
  }
}
