part of 'supabase_admin_repository.dart';

abstract class _SupabaseAdminRepositoryBase {
  const _SupabaseAdminRepositoryBase({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
    LocalPinHasher pinHasher = const LocalPinHasher(),
  }) : _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client,
       _pinHasher = pinHasher;

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;
  final LocalPinHasher _pinHasher;

  Future<AppResult<T>> _guard<T>(
    String code,
    String message,
    Future<T> Function() action,
  ) async {
    try {
      _ensureConfigured();
      return AppSuccess(await action());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(code: code, message: message, cause: error),
      );
    }
  }

  void _ensureConfigured() {
    if (!_config.isConfigured ||
        !_restaurantService.isConfigured ||
        _remoteSessionService.accessToken == null) {
      throw StateError('Se requiere sesion administrativa remota.');
    }
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

  Future<void> _upsert(
    String table,
    Map<String, Object?> payload, {
    String conflictColumn = 'id',
  }) async {
    final response = await _client.post(
      _config.restUri(table, {'on_conflict': conflictColumn}),
      headers: _headers(prefer: 'resolution=merge-duplicates,return=minimal'),
      body: jsonEncode(payload),
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
      headers: _headers(prefer: 'return=minimal'),
      body: jsonEncode(payload),
    );
    _ensureSuccess(response, table);
  }

  Future<void> _deleteWhere(String table, Map<String, String> query) async {
    final response = await _client.delete(
      _config.restUri(table, query),
      headers: _headers(prefer: 'return=minimal'),
    );
    _ensureSuccess(response, table);
  }

  Future<Map<String, Object?>> _rpc(
    String functionName,
    Map<String, Object?> body,
  ) async {
    final response = await _client.post(
      _config.rpcUri(functionName),
      headers: _headers(),
      body: jsonEncode(body),
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

  Map<String, String> _headers({String? prefer}) {
    final token = _remoteSessionService.accessToken;
    if (token == null) throw StateError('Sesion remota expirada.');
    return {
      'apikey': _config.publishableKey,
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'accept': 'application/json',
      // ignore: use_null_aware_elements, SDK infers String? as map value.
      if (prefer case final value?) 'prefer': value,
    };
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

  ProductCategory _categoryFromRow(Map<String, Object?> row) {
    return ProductCategory(
      id: _text(row['id']),
      name: _text(row['name']),
      parentId: _nullableText(row['parent_id']),
      sortOrder: _int(row['display_order']),
      isActive: _bool(row['is_active'], fallback: true),
    );
  }

  PaymentMethod _paymentMethodFromRow(Map<String, Object?> row) {
    return PaymentMethod(
      id: _text(row['id']),
      name: _text(row['name']),
      parentId: _nullableText(row['parent_id']),
      groupName: _text(row['group_name'], fallback: 'Otros'),
      currencyCode: _nullableText(row['currency_code']),
      displayOrder: _int(row['display_order']),
      isPaymentTarget: _bool(row['is_payment_target'], fallback: true),
      affectsCashRegister: _bool(row['affects_cash']),
      requiresReference: _bool(row['requires_reference']),
      isActive: _bool(row['is_active'], fallback: true),
    );
  }

  TableAccount _tableAccountFromRow(Map<String, Object?> row) {
    return TableAccount(
      id: _text(row['id']),
      tableId: _text(row['table_id']),
      name: _text(row['name']),
      status: TableAccountStatus.values.firstWhere(
        (status) => status.name == _text(row['status']),
        orElse: () => TableAccountStatus.open,
      ),
    );
  }

  ExchangeRate _exchangeRateFromRow(Map<String, Object?> row) {
    return ExchangeRate(
      currencyCode: _text(row['currency_code']),
      businessDate: _date(row['business_date']),
      rateInCents: _moneyToCents(row['rate']),
    );
  }

  SalesType _salesTypeFromRow(Map<String, Object?> row) {
    return SalesType(
      id: _text(row['id']),
      code: _text(row['code']),
      name: _text(row['name']),
      displayOrder: _int(row['display_order']),
      isDefault: _bool(row['is_default']),
      isActive: _bool(row['is_active'], fallback: true),
    );
  }

  ProductPackagingRule _packagingRuleFromRow(Map<String, Object?> row) {
    return ProductPackagingRule(
      id: _text(row['id']),
      productId: _text(row['product_id']),
      salesTypeId: _text(row['sales_type_id']),
      packagingItemId: _text(row['packaging_item_id']),
      quantityPerUnit: _int(row['quantity_per_unit'], fallback: 1),
      isActive: _bool(row['is_active'], fallback: true),
    );
  }

  AppUserProfile _withUpdatedPin(AppUserProfile user, String? pin) {
    final normalizedPin = pin?.trim();
    if (normalizedPin == null || normalizedPin.isEmpty) return user;
    final salt = _pinHasher.generateSalt();
    final hash = _pinHasher.hashPin(pin: normalizedPin, salt: salt);
    return user.copyWith(pinSalt: salt, pinHash: hash);
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

  String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int _int(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _bool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value == null) return fallback;
    return value.toString().toLowerCase() == 'true';
  }

  int _moneyToCents(Object? value) {
    if (value is int) return value * 100;
    if (value is num) return (value * 100).round();
    return ((num.tryParse(value?.toString() ?? '') ?? 0) * 100).round();
  }

  num _money(int cents) => cents / 100;

  DateTime _date(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return DateTime.now();
    return DateTime.tryParse(text) ?? DateTime.now();
  }

  String _dateOnly(DateTime value) {
    return value.toIso8601String().substring(0, 10);
  }

  String? _uuidOrNull(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final uuid = RegExp(
      '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-'
      '[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      '[0-9a-fA-F]{12}'
      r'$',
    );
    return uuid.hasMatch(text) ? text : null;
  }

  String get _restaurantId => _restaurantService.restaurantId;

  String get _remoteUserId {
    final userId = _remoteSessionService.userId;
    if (userId == null || userId.isEmpty) {
      throw StateError('No se pudo resolver el administrador remoto.');
    }
    return userId;
  }
}
