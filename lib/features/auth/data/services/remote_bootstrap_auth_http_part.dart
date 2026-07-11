part of 'remote_bootstrap_auth_service.dart';

extension _RemoteBootstrapAuthHttp on RemoteBootstrapAuthService {
  Future<List<Map<String, Object?>>> _rows({
    required String accessToken,
    required String table,
    required Map<String, String> query,
  }) async {
    final response = await _client.get(
      _config.restUri(table, query),
      headers: _headers(accessToken),
    );
    _ensureSuccess(response, table);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw StateError('Respuesta invalida de $table.');
    }
    return decoded.map(_mapRow).toList();
  }

  Map<String, String> _headers(String accessToken) {
    return {
      'apikey': _config.publishableKey,
      'authorization': 'Bearer $accessToken',
      'accept': 'application/json',
    };
  }

  Map<String, String> _jsonHeaders(String accessToken) {
    return {
      ..._headers(accessToken),
      'content-type': 'application/json',
    };
  }

  void _ensureConfigured() {
    if (!_config.isConfigured || !_restaurantService.isConfigured) {
      throw StateError('Supabase no esta configurado para inicializar.');
    }
  }

  void _ensureSuccess(http.Response response, String table) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _SupabaseHttpException(
        table: table,
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  String _remoteLoginMessage(_SupabaseHttpException error) {
    if (error.table == 'auth') {
      final body = error.body.toLowerCase();
      if (error.statusCode == 400 &&
          (body.contains('invalid_credentials') ||
              body.contains('invalid login credentials'))) {
        return 'Correo o clave remota incorrectos en Supabase Auth.';
      }
      if (error.statusCode == 400 && body.contains('email_not_confirmed')) {
        return 'El correo remoto existe, pero falta confirmar la cuenta '
            'en Supabase.';
      }
      return 'Supabase Auth rechazo el inicio de sesion remoto.';
    }

    if (error.table == 'profiles') {
      return 'No se pudo leer el perfil remoto del administrador.';
    }

    if (error.table == 'permissions' || error.table == 'role_permissions') {
      return 'No se pudieron validar los permisos remotos del administrador.';
    }

    return 'No se pudo validar el administrador remoto.';
  }

  String _unexpectedRemoteLoginMessage(Object error) {
    final text = error.toString();
    if (text.contains('No existe perfil remoto')) {
      return 'La clave remota es correcta, pero no existe perfil remoto '
          'para este administrador.';
    }
    if (text.contains('Supabase no esta configurado')) {
      return 'Supabase no esta configurado para inicializar este dispositivo.';
    }
    return 'No se pudo validar el administrador remoto. Detalle: $text';
  }

  Map<String, Object?> _decodeObject(String body, {required String table}) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return _mapRow(decoded);
    throw StateError('Respuesta invalida de $table.');
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
    if (text == null) throw StateError('Fila remota de $table sin id valido.');
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

  AppFailureResult<T> _failure<T>(String code, String message) {
    return AppFailureResult(AppFailure(code: code, message: message));
  }
}

final class _AuthUser {
  const _AuthUser({required this.id, required this.email});

  final String id;
  final String? email;
}

final class _RemoteAuthTokens {
  const _RemoteAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}
