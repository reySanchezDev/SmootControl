part of 'supabase_product_recipes_service.dart';

extension _RecipeServiceRows on SupabaseProductRecipesService {
  Future<List<ProductRecipeLine>> _recipeLines(String recipeId) async {
    final rows = await _getRows('product_recipe_lines', {
      'recipe_id': 'eq.$recipeId',
      'is_active': 'eq.true',
      'select':
          'component_product_id,quantity,unit_id,waste_percent,display_order,'
          'products(name),measurement_units(name,code)',
      'order': 'display_order.asc',
    });
    return rows.map(_lineFromRow).toList();
  }

  ProductRecipeLine _lineFromRow(Map<String, Object?> row) {
    final unit = _map(row['measurement_units']);
    return ProductRecipeLine(
      componentProductId: _text(row['component_product_id']),
      componentName: _text(_map(row['products'])['name']),
      quantity: _double(row['quantity']),
      unitId: _text(row['unit_id']),
      unitName: _unitLabel(unit),
      wastePercent: _double(row['waste_percent']),
      displayOrder: _int(row['display_order']),
    );
  }

  Future<List<Map<String, Object?>>> _getRows(
    String table,
    Map<String, String> query,
  ) async {
    final response = await _client.get(
      _config.restUri(table, query),
      headers: _headers(),
    );
    _ensureSuccess(response, table);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map((row) => row.cast<String, Object?>())
        .toList();
  }

  Future<void> _postRpc(String functionName, Map<String, Object?> body) async {
    final response = await _client.post(
      _config.rpcUri(functionName),
      headers: _headers(),
      body: jsonEncode(body),
    );
    _ensureSuccess(response, functionName);
  }

  Map<String, String> _headers() {
    final token = _remoteSessionService.accessToken;
    if (token == null) throw StateError('Sesion remota expirada.');
    return {
      'apikey': _config.publishableKey,
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'accept': 'application/json',
    };
  }

  void _ensureReady() {
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        _remoteSessionService.accessToken == null) {
      throw StateError('Se requiere sesion administrativa remota.');
    }
  }

  void _ensureSuccess(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      _remoteSessionService.expire();
    }
    throw StateError(
      'Supabase rechazo $operation (${response.statusCode}): ${response.body}',
    );
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _unitLabel(Map<String, Object?> unit) {
    final name = _text(unit['name']);
    final code = _text(unit['code']);
    if (name.isEmpty) return null;
    return code.isEmpty ? name : '$name ($code)';
  }
}
