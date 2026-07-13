part of 'supabase_catalog_pull_service.dart';

extension on SupabaseCatalogPullService {
  Future<List<Map<String, Object?>>> _getRows(
    String table, {
    String select = '*',
  }) async {
    return _getRowsByQuery(table, {
      'restaurant_id': 'eq.${_restaurantService.restaurantId}',
      'select': select,
    });
  }

  Future<List<Map<String, Object?>>> _getRowsIncludingGlobal(
    String table, {
    String select = '*',
  }) async {
    final restaurantId = _restaurantService.restaurantId;
    return _getRowsByQuery(table, {
      'or': '(restaurant_id.is.null,restaurant_id.eq.$restaurantId)',
      'select': select,
    });
  }

  Future<List<Map<String, Object?>>> _getGlobalRows(
    String table, {
    String select = '*',
  }) async {
    return _getRowsByQuery(table, {
      'restaurant_id': 'is.null',
      'select': select,
    });
  }

  Future<List<Map<String, Object?>>> _getRowsByQuery(
    String table,
    Map<String, String> query,
  ) async {
    final deviceRows = _deviceCatalogRows;
    if (deviceRows != null) {
      return _rowsFromDeviceCatalog(deviceRows, table, query);
    }

    final response = await _client.get(
      _config.restUri(table, query),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _remoteSessionService.expire();
      }
      throw StateError(
        'Supabase rechazo descarga de $table (${response.statusCode}): '
        '${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw StateError('Respuesta invalida descargando $table.');
    }

    return decoded.map(_mapRow).toList();
  }

  Future<void> _prepareDeviceCatalogIfNeeded() async {
    if (_hasRemoteCatalogToken) return;
    _deviceCatalogRows = await _pullOperationalCatalogWithDevice();
  }

  Future<Map<String, List<Map<String, Object?>>>>
  _pullOperationalCatalogWithDevice() async {
    final credentials = await _deviceCredentials();
    final response = await _client.post(
      _config.rpcUri('pos_pull_operational_catalog'),
      headers: {
        'apikey': _config.publishableKey,
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'p_restaurant_id': _restaurantService.restaurantId,
        'p_device_id': credentials.deviceId,
        'p_device_secret': credentials.deviceSecret,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Supabase rechazo descarga POS (${response.statusCode}): '
        '${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Respuesta invalida descargando catalogo POS.');
    }

    return decoded.map((key, value) {
      final rows = value is List
          ? value.map(_mapRow).toList(growable: false)
          : <Map<String, Object?>>[];
      return MapEntry(key.toString(), rows);
    });
  }

  List<Map<String, Object?>> _rowsFromDeviceCatalog(
    Map<String, List<Map<String, Object?>>> snapshot,
    String table,
    Map<String, String> query,
  ) {
    Iterable<Map<String, Object?>> rows = snapshot[table] ?? const [];

    for (final entry in query.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == 'select' || key == 'limit') continue;
      if (key == 'or') {
        rows = _applyDeviceOrFilter(rows, value);
        continue;
      }
      rows = _applyDeviceFilter(rows, key, value);
    }

    final limit = int.tryParse(query['limit'] ?? '');
    if (limit != null && limit >= 0) rows = rows.take(limit);
    return rows.toList();
  }

  Iterable<Map<String, Object?>> _applyDeviceFilter(
    Iterable<Map<String, Object?>> rows,
    String key,
    String expression,
  ) {
    if (expression.startsWith('eq.')) {
      final expected = expression.substring(3);
      return rows.where((row) => _optionalText(row[key]) == expected);
    }
    if (expression == 'is.null') {
      return rows.where((row) => _optionalText(row[key]) == null);
    }
    return rows;
  }

  Iterable<Map<String, Object?>> _applyDeviceOrFilter(
    Iterable<Map<String, Object?>> rows,
    String expression,
  ) {
    final normalized = expression.trim();
    if (!normalized.startsWith('(') || !normalized.endsWith(')')) {
      return rows;
    }
    final clauses = normalized
        .substring(1, normalized.length - 1)
        .split(',')
        .map((clause) => clause.trim())
        .where((clause) => clause.isNotEmpty)
        .toList();
    if (clauses.isEmpty) return rows;

    return rows.where((row) {
      for (final clause in clauses) {
        final isNullParts = clause.split('.is.');
        if (isNullParts.length == 2 && isNullParts[1] == 'null') {
          if (_optionalText(row[isNullParts[0]]) == null) return true;
          continue;
        }

        final eqParts = clause.split('.eq.');
        if (eqParts.length == 2 &&
            _optionalText(row[eqParts[0]]) == eqParts[1]) {
          return true;
        }
      }
      return false;
    });
  }

  Future<void> _ensureDefaultSalesTypes() async {
    final response = await _client.post(
      _config.restUri('rpc/ensure_default_sales_types'),
      headers: {
        ...await _headers(),
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'p_restaurant_id': _restaurantService.restaurantId,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _remoteSessionService.expire();
      }
      throw StateError(
        'Supabase rechazo creacion de tipos de venta base '
        '(${response.statusCode}): ${response.body}',
      );
    }
  }

  Map<String, List<String>> _modifierIdsByProduct(
    List<Map<String, Object?>> rows,
  ) {
    final grouped = <String, List<_ProductModifierLink>>{};
    for (final row in rows) {
      final productId = _optionalText(row['product_id']);
      final groupId = _optionalText(row['modifier_group_id']);
      if (productId == null || groupId == null) continue;
      grouped
          .putIfAbsent(productId, () => [])
          .add(_ProductModifierLink(groupId, _int(row['display_order'])));
    }

    return grouped.map((productId, links) {
      links.sort((first, second) => first.order.compareTo(second.order));
      return MapEntry(productId, links.map((link) => link.groupId).toList());
    });
  }
}
