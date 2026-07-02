import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/auth/domain/services/remote_bootstrap_session.dart';

/// Authenticates a real remote administrator before restoring a tablet.
final class RemoteBootstrapAuthService {
  /// Creates a remote bootstrap auth service.
  const RemoteBootstrapAuthService({
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required CurrentRemoteSessionService remoteSessionService,
    required http.Client client,
  }) : _config = config,
       _restaurantService = restaurantService,
       _remoteSessionService = remoteSessionService,
       _client = client;

  /// Permission required to initialize or restore a clean device.
  static const initializePermissionCode = 'dispositivo.inicializar';

  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final CurrentRemoteSessionService _remoteSessionService;
  final http.Client _client;

  /// Checks whether the remote tenant already has users/profiles.
  Future<AppResult<bool>> hasRemoteProfiles() async {
    try {
      _ensureConfigured();
      final response = await _client.post(
        _config.rpcUri('bootstrap_status'),
        headers: {
          'apikey': _config.publishableKey,
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({
          'p_restaurant_id': _restaurantService.restaurantId,
        }),
      );
      _ensureSuccess(response, 'bootstrap_status');
      final decoded = _decodeObject(response.body, table: 'bootstrap_status');
      return AppSuccess(_bool(decoded['has_profiles']));
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'device_init_status_failed',
          message: 'No se pudo validar el estado inicial de Supabase.',
          cause: error,
        ),
      );
    }
  }

  /// Creates the first remote administrator in a clean Supabase tenant.
  Future<AppResult<RemoteBootstrapSession>> createFirstAdmin({
    required String displayName,
    required String email,
    required String password,
    required String pinSalt,
    required String pinHash,
  }) async {
    try {
      _ensureConfigured();
      final signUpResult = await _signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (signUpResult == _SignUpResult.existing) {
        try {
          await _passwordGrant(email: email, password: password);
        } on _SupabaseHttpException catch (error) {
          return AppFailureResult(
            AppFailure(
              code: 'device_init_existing_auth_password_mismatch',
              message:
                  'Ese correo ya existe en Supabase Auth, pero la clave '
                  'remota no coincide.',
              cause: error,
            ),
          );
        }
      }

      final response = await _client.post(
        _config.rpcUri('bootstrap_first_admin'),
        headers: {
          'apikey': _config.publishableKey,
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({
          'p_restaurant_id': _restaurantService.restaurantId,
          'p_email': email.trim().toLowerCase(),
          'p_display_name': displayName.trim(),
          'p_pin_salt': pinSalt,
          'p_pin_hash': pinHash,
        }),
      );
      _ensureSuccess(response, 'bootstrap_first_admin');
      return signIn(email: email, password: password);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'device_init_first_admin_failed',
          message: 'No se pudo crear el administrador remoto inicial.',
          cause: error,
        ),
      );
    }
  }

  /// Signs in with Supabase Auth and validates the bootstrap permission.
  Future<AppResult<RemoteBootstrapSession>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _ensureConfigured();
      final auth = await _passwordGrant(email: email, password: password);
      final authUser = await _authUser(auth.accessToken);
      final profile = await _profileFor(
        accessToken: auth.accessToken,
        authUserId: authUser.id,
        email: authUser.email ?? email,
      );

      if (!_bool(profile['is_active'], defaultValue: true)) {
        return _failure(
          'device_init_user_inactive',
          'El usuario remoto esta inactivo.',
        );
      }

      final roleId = _optionalText(profile['role_id']);
      if (roleId == null) {
        return _failure(
          'device_init_missing_role',
          'El usuario remoto no tiene rol asignado.',
        );
      }

      final hasPermission = await _hasInitializePermission(
        accessToken: auth.accessToken,
        roleId: roleId,
      );
      if (!hasPermission) {
        return _failure(
          'device_init_permission_denied',
          'Este usuario no tiene permiso para inicializar dispositivos.',
        );
      }

      final profileId = _requiredText(profile['id'], table: 'profiles');
      _remoteSessionService.set(
        accessToken: auth.accessToken,
        userId: profileId,
        expiresAt: auth.expiresAt,
      );

      return AppSuccess(
        RemoteBootstrapSession(
          accessToken: auth.accessToken,
          refreshToken: auth.refreshToken,
          expiresAt: auth.expiresAt,
          userId: profileId,
          email: _text(profile['email'], defaultValue: authUser.email ?? email),
          displayName: _text(
            profile['display_name'],
            defaultValue: 'Administrador',
          ),
          roleId: roleId,
          restaurantId: _restaurantService.restaurantId,
          hasLocalPin:
              _optionalText(profile['pin_salt']) != null &&
              _optionalText(profile['pin_hash']) != null,
        ),
      );
    } on _SupabaseHttpException catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'device_init_remote_login_failed',
          message: _remoteLoginMessage(error),
          cause: error,
        ),
      );
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'device_init_remote_login_failed',
          message: _unexpectedRemoteLoginMessage(error),
          cause: error,
        ),
      );
    }
  }

  Future<_SignUpResult> _signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.post(
      _config.signupUri,
      headers: {
        'apikey': _config.publishableKey,
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
        'data': {'display_name': displayName.trim()},
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _SignUpResult.created;
    }

    final body = response.body.toLowerCase();
    if (response.statusCode == 400 &&
        (body.contains('already') || body.contains('registered'))) {
      return _SignUpResult.existing;
    }

    _ensureSuccess(response, 'auth signup');
    return _SignUpResult.created;
  }

  /// Stores a local PIN hash in the remote profile.
  Future<AppResult<RemoteBootstrapSession>> updateRemotePin({
    required RemoteBootstrapSession session,
    required String salt,
    required String hash,
  }) async {
    try {
      final response = await _client.patch(
        _config.restUri('profiles', {
          'id': 'eq.${session.userId}',
          'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        }),
        headers: _jsonHeaders(session.accessToken)
          ..['prefer'] = 'return=minimal',
        body: jsonEncode({
          'pin_salt': salt,
          'pin_hash': hash,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      _ensureSuccess(response, 'profiles');
      return AppSuccess(session.withLocalPin());
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'device_init_pin_update_failed',
          message: 'No se pudo guardar el PIN en Supabase.',
          cause: error,
        ),
      );
    }
  }

  /// Registers this installation as an authorized POS sync device.
  Future<AppResult<void>> registerSyncDevice({
    required RemoteBootstrapSession session,
    required String deviceId,
    required String deviceSecret,
  }) async {
    try {
      final response = await _client.post(
        _config.rpcUri('register_pos_device'),
        headers: _jsonHeaders(session.accessToken),
        body: jsonEncode({
          'p_restaurant_id': _restaurantService.restaurantId,
          'p_device_id': deviceId,
          'p_device_secret': deviceSecret,
          'p_name': 'POS ${DateTime.now().toIso8601String()}',
        }),
      );
      _ensureSuccess(response, 'register_pos_device');
      return const AppSuccess(null);
    } on Object catch (error) {
      return AppFailureResult(
        AppFailure(
          code: 'device_sync_registration_failed',
          message: 'No se pudo registrar el dispositivo para sincronizar.',
          cause: error,
        ),
      );
    }
  }

  Future<_RemoteAuthTokens> _passwordGrant({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _config.passwordGrantUri,
      headers: {
        'apikey': _config.publishableKey,
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );
    _ensureSuccess(response, 'auth');
    final decoded = _decodeObject(response.body, table: 'auth');
    final token = _optionalText(decoded['access_token']);
    if (token == null) {
      throw StateError('Supabase no devolvio access_token.');
    }
    final refreshToken = _optionalText(decoded['refresh_token']);
    if (refreshToken == null) {
      throw StateError('Supabase no devolvio refresh_token.');
    }
    final expiresIn = decoded['expires_in'];
    final expiresAt = DateTime.now().add(
      Duration(seconds: expiresIn is int ? expiresIn : 3600),
    );
    return _RemoteAuthTokens(
      accessToken: token,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  Future<_AuthUser> _authUser(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${_config.supabaseUrl}/auth/v1/user'),
      headers: {
        'apikey': _config.publishableKey,
        'authorization': 'Bearer $accessToken',
        'accept': 'application/json',
      },
    );
    _ensureSuccess(response, 'auth user');
    final decoded = _decodeObject(response.body, table: 'auth user');
    return _AuthUser(
      id: _requiredText(decoded['id'], table: 'auth user'),
      email: _optionalText(decoded['email']),
    );
  }

  Future<Map<String, Object?>> _profileFor({
    required String accessToken,
    required String authUserId,
    required String email,
  }) async {
    final byId = await _rows(
      accessToken: accessToken,
      table: 'profiles',
      query: {
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'id': 'eq.$authUserId',
        'select': '*',
        'limit': '1',
      },
    );
    if (byId.isNotEmpty) return byId.first;

    final byEmail = await _rows(
      accessToken: accessToken,
      table: 'profiles',
      query: {
        'restaurant_id': 'eq.${_restaurantService.restaurantId}',
        'email': 'eq.${email.trim().toLowerCase()}',
        'select': '*',
        'limit': '1',
      },
    );
    if (byEmail.isNotEmpty) return byEmail.first;

    throw StateError('No existe perfil remoto para este usuario.');
  }

  Future<bool> _hasInitializePermission({
    required String accessToken,
    required String roleId,
  }) async {
    final permissions = await _rows(
      accessToken: accessToken,
      table: 'permissions',
      query: {
        'code': 'eq.$initializePermissionCode',
        'select': 'id,code',
        'limit': '1',
      },
    );
    if (permissions.isEmpty) return false;

    final permissionId = _optionalText(permissions.first['id']);
    if (permissionId == null) return false;

    final assignments = await _rows(
      accessToken: accessToken,
      table: 'role_permissions',
      query: {
        'role_id': 'eq.$roleId',
        'permission_id': 'eq.$permissionId',
        'select': 'role_id,permission_id',
        'limit': '1',
      },
    );
    return assignments.isNotEmpty;
  }

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

enum _SignUpResult { created, existing }

final class _SupabaseHttpException implements Exception {
  const _SupabaseHttpException({
    required this.table,
    required this.statusCode,
    required this.body,
  });

  final String table;
  final int statusCode;
  final String body;

  @override
  String toString() {
    return 'Supabase rechazo $table ($statusCode): $body';
  }
}
