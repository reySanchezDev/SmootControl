import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:smoo_control/core/config/supabase_app_config.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_restaurant_service.dart';
import 'package:smoo_control/features/auth/data/services/remote_bootstrap_auth_service.dart';
import 'package:smoo_control/features/auth/domain/services/local_pin_hasher.dart';
import 'package:smoo_control/features/auth/domain/services/remote_bootstrap_session.dart';
import 'package:smoo_control/features/sync/data/datasources/supabase_catalog_pull_service.dart';
import 'package:smoo_control/features/sync/domain/services/catalog_pull_summary.dart';
import 'package:uuid/uuid.dart';

part 'device_initialization_local_support.dart';

/// Startup mode for an unauthenticated app instance.
enum DeviceStartupMode {
  /// A local user with PIN exists, so normal offline login is available.
  localLogin,

  /// Supabase is configured and the clean device must be restored remotely.
  remoteInitialization,

  /// Supabase is configured but the tenant has no remote admin yet.
  remoteInitialSetup,

  /// Supabase is not configured, so local/demo setup is allowed.
  localInitialSetup,
}

/// Coordinates secure initialization of a clean tablet from Supabase.
final class DeviceInitializationService {
  /// Creates a device initialization service.
  const DeviceInitializationService({
    required AppDatabase database,
    required SupabaseAppConfig config,
    required CurrentRestaurantService restaurantService,
    required RemoteBootstrapAuthService remoteAuthService,
    required SupabaseCatalogPullService catalogPullService,
    LocalPinHasher pinHasher = const LocalPinHasher(),
    Uuid uuid = const Uuid(),
  }) : _database = database,
       _config = config,
       _restaurantService = restaurantService,
       _remoteAuthService = remoteAuthService,
       _catalogPullService = catalogPullService,
       _pinHasher = pinHasher,
       _uuid = uuid;

  final AppDatabase _database;
  final SupabaseAppConfig _config;
  final CurrentRestaurantService _restaurantService;
  final RemoteBootstrapAuthService _remoteAuthService;
  final SupabaseCatalogPullService _catalogPullService;
  final LocalPinHasher _pinHasher;
  final Uuid _uuid;

  /// Determines the first screen for an unauthenticated startup.
  Future<AppResult<DeviceStartupMode>> getStartupMode() async {
    try {
      if (_config.isConfigured && _restaurantService.isConfigured) {
        final state = await _deviceState();
        if (state?.lastRestoreStatus == 'failed') {
          return const AppSuccess(DeviceStartupMode.remoteInitialization);
        }

        if (await _hasLocalPinUser()) {
          return const AppSuccess(DeviceStartupMode.localLogin);
        }

        final hasProfilesResult = await _remoteAuthService.hasRemoteProfiles();
        if (hasProfilesResult case AppSuccess<bool>(value: false)) {
          return const AppSuccess(DeviceStartupMode.remoteInitialSetup);
        }

        return const AppSuccess(DeviceStartupMode.remoteInitialization);
      }

      if (await _hasLocalPinUser()) {
        return const AppSuccess(DeviceStartupMode.localLogin);
      }

      return const AppSuccess(DeviceStartupMode.localInitialSetup);
    } on Object catch (error) {
      return _failure(
        'device_startup_mode_failed',
        'No se pudo validar el modo de inicio.',
        error,
      );
    }
  }

  Future<LocalDeviceStateData?> _deviceState() {
    return (_database.select(
      _database.localDeviceState,
    )..where((row) => row.id.equals('default'))).getSingleOrNull();
  }

  /// Authenticates a remote administrator for initialization.
  Future<AppResult<RemoteBootstrapSession>> signInRemoteAdmin({
    required String email,
    required String password,
  }) {
    return _remoteAuthService.signIn(email: email, password: password);
  }

  /// Creates the first remote administrator and restores this device.
  Future<AppResult<CatalogPullSummary>> createFirstRemoteAdminAndRestore({
    required String displayName,
    required String email,
    required String password,
    required String pin,
    String? deviceDisplayName,
  }) async {
    final salt = _pinHasher.generateSalt();
    final hash = _pinHasher.hashPin(pin: pin, salt: salt);
    final sessionResult = await _remoteAuthService.createFirstAdmin(
      displayName: displayName,
      email: email,
      password: password,
      pinSalt: salt,
      pinHash: hash,
    );

    return switch (sessionResult) {
      AppFailureResult(:final error) => AppFailureResult(error),
      AppSuccess(:final value) => restoreDevice(
        session: value,
        deviceDisplayName: deviceDisplayName,
      ),
    };
  }

  /// Creates the remote/local PIN hash for an authenticated administrator.
  Future<AppResult<RemoteBootstrapSession>> configureRemotePin({
    required RemoteBootstrapSession session,
    required String pin,
  }) async {
    final salt = _pinHasher.generateSalt();
    final hash = _pinHasher.hashPin(pin: pin, salt: salt);
    return _remoteAuthService.updateRemotePin(
      session: session,
      salt: salt,
      hash: hash,
    );
  }

  /// Restores the full operational dataset and marks this device initialized.
  Future<AppResult<CatalogPullSummary>> restoreDevice({
    required RemoteBootstrapSession session,
    String? deviceDisplayName,
  }) async {
    try {
      final summary = await _catalogPullService
          .pullOperationalCatalogWithAccessToken(session.accessToken);

      final missing = [...summary.missingInitializationRequirements];
      if (!await _hasLocalPinUser()) {
        missing.add('usuarios con PIN local');
      }

      if (missing.isNotEmpty) {
        final message = 'Faltan datos para operar POS: ${missing.join(', ')}.';
        await _markRestoreFailed(session: session, error: message);
        return const AppFailureResult(
          AppFailure(
            code: 'device_restore_incomplete',
            message:
                'La restauracion no tiene todos los datos necesarios '
                'para inicializar el dispositivo.',
          ),
        );
      }

      await _markInitialized(
        session: session,
        summary: summary,
        deviceDisplayName: deviceDisplayName,
      );
      return AppSuccess(summary);
    } on Object catch (error) {
      await _markRestoreFailed(session: session, error: error.toString());
      return AppFailureResult(
        AppFailure(
          code: 'device_restore_failed',
          message: 'No se pudo restaurar la tableta desde Supabase.',
          cause: error,
        ),
      );
    }
  }

  AppFailureResult<T> _failure<T>(
    String code,
    String message,
    Object error,
  ) {
    return AppFailureResult(
      AppFailure(code: code, message: message, cause: error),
    );
  }
}
