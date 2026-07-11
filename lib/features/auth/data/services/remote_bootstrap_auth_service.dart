import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/auth/domain/services/remote_bootstrap_session.dart';

part 'remote_bootstrap_auth_http_part.dart';
part 'remote_bootstrap_auth_models_part.dart';
part 'remote_bootstrap_auth_remote_part.dart';

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
}
