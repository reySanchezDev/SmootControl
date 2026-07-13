part of 'supabase_catalog_pull_service.dart';

extension on SupabaseCatalogPullService {
  Future<void> _ensureCanPull() async {
    if (!_config.isConfigured || !_restaurantService.isConfigured) {
      throw StateError('Supabase no esta configurado para descargar datos.');
    }
    if (_hasRemoteCatalogToken || await _hasDeviceCredentials()) return;
    throw StateError(
      'Inicializa este dispositivo o inicia sesion como administrador remoto '
      'para descargar datos.',
    );
  }

  bool get _hasRemoteCatalogToken {
    return (_accessToken != null && _accessToken!.isNotEmpty) ||
        _remoteSessionService.hasUsableToken;
  }

  Future<Map<String, String>> _headers() async {
    return {
      'apikey': _config.publishableKey,
      'authorization': 'Bearer ${await _authToken()}',
      'accept': 'application/json',
    };
  }

  Future<String> _authToken() async {
    final token = _accessToken;
    final expiration = _expiresAt;
    if (token != null &&
        expiration != null &&
        expiration.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return token;
    }

    if (_temporaryTokenOnly) {
      throw StateError(
        'La sesion remota de inicializacion expiro. Inicia sesion nuevamente.',
      );
    }

    final sessionToken = _remoteSessionService.accessToken;
    if (sessionToken != null) return sessionToken;

    throw StateError(
      'La sesion remota expiro. Inicia sesion como administrador remoto.',
    );
  }

  Future<_DeviceCatalogCredentials> _deviceCredentials() async {
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
    return _DeviceCatalogCredentials(
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

  Map<String, Object?> _mapRow(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  String _requiredText(Object? value, {required String table}) {
    final text = _optionalText(value);
    if (text == null) {
      throw StateError('Fila remota de $table sin id valido.');
    }
    return text;
  }

  String _text(Object? value, {required String defaultValue}) {
    return _optionalText(value) ?? defaultValue;
  }

  String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  bool _bool(Object? value, {bool defaultValue = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return defaultValue;
  }

  int _int(Object? value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  int _moneyCents(Object? value) {
    if (value is int) return value * 100;
    if (value is num) return (value * 100).round();
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return (parsed * 100).round();
    }
    return 0;
  }

  int? _moneyCentsOrNull(Object? value) {
    if (value == null) return null;
    return _moneyCents(value);
  }

  DateTime? _date(Object? value) {
    final text = _optionalText(value);
    if (text == null) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _jsonListText(Object? value) {
    if (value is String) return value;
    if (value is List) return jsonEncode(value);
    return '[]';
  }
}
