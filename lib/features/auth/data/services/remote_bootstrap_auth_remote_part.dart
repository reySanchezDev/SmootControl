part of 'remote_bootstrap_auth_service.dart';

extension _RemoteBootstrapAuthRemote on RemoteBootstrapAuthService {
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
        'code': 'eq.${RemoteBootstrapAuthService.initializePermissionCode}',
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
}
