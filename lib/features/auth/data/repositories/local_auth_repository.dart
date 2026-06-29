import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';
import 'package:smoo_control/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:smoo_control/features/auth/domain/services/local_pin_hasher.dart';
import 'package:smoo_control/features/roles/domain/services/access_seed_service.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';
import 'package:uuid/uuid.dart';

/// Local offline authentication repository backed by app users.
final class LocalAuthRepository implements IAuthRepository {
  /// Creates a local authentication repository.
  const LocalAuthRepository({
    required AppDatabase database,
    required AccessSeedService seedService,
    required CurrentOperatorService currentOperatorService,
    LocalPinHasher pinHasher = const LocalPinHasher(),
    Uuid uuid = const Uuid(),
  }) : _database = database,
       _seedService = seedService,
       _currentOperatorService = currentOperatorService,
       _pinHasher = pinHasher,
       _uuid = uuid;

  final AppDatabase _database;
  final AccessSeedService _seedService;
  final CurrentOperatorService _currentOperatorService;
  final LocalPinHasher _pinHasher;
  final Uuid _uuid;

  @override
  Future<AppResult<AuthSession?>> getCurrentSession() async {
    return AppSuccess(_currentOperatorService.session);
  }

  @override
  Future<AppResult<bool>> isInitialSetupRequired() async {
    try {
      final query = _database.select(_database.localUserProfiles)
        ..where((user) {
          return user.isActive.equals(true) &
              user.pinSalt.isNotNull() &
              user.pinHash.isNotNull();
        })
        ..limit(1);
      final users = await query.get();

      return AppSuccess(users.isEmpty);
    } on Object catch (error) {
      return _failure(
        'auth_setup_check_failed',
        'No se pudo validar la configuracion inicial.',
        error,
      );
    }
  }

  @override
  Future<AppResult<AuthSession>> signInWithPin({
    required String email,
    required String pin,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final query = _database.select(_database.localUserProfiles)
        ..where(
          (user) => user.email.lower().equals(normalizedEmail),
        )
        ..limit(1);
      final user = await query.getSingleOrNull();

      if (user == null || !user.isActive) {
        return _invalidCredentials();
      }

      final pinSalt = user.pinSalt;
      final pinHash = user.pinHash;
      if (pinSalt == null || pinHash == null) {
        return _failure(
          'auth_pin_not_configured',
          'Este usuario no tiene PIN configurado.',
          null,
        );
      }

      final valid = _pinHasher.verify(pin: pin, salt: pinSalt, hash: pinHash);
      if (!valid) {
        return _invalidCredentials();
      }

      final seedResult = await _seedService.ensureSeeded();
      if (seedResult case AppFailureResult(:final error)) {
        return AppFailureResult(error);
      }

      return AppSuccess(_setCurrentSession(user));
    } on Object catch (error) {
      return _failure(
        'auth_sign_in_failed',
        'No se pudo iniciar sesion.',
        error,
      );
    }
  }

  @override
  Future<AppResult<AuthSession>> createInitialAdmin({
    required String displayName,
    required String email,
    required String pin,
  }) async {
    try {
      final setupResult = await isInitialSetupRequired();
      if (setupResult case AppFailureResult(:final error)) {
        return AppFailureResult(error);
      }
      if (setupResult case AppSuccess<bool>(value: false)) {
        return _failure(
          'auth_setup_already_completed',
          'La configuracion inicial ya fue completada.',
          null,
        );
      }

      final seedResult = await _seedService.ensureSeeded();
      if (seedResult case AppFailureResult(:final error)) {
        return AppFailureResult(error);
      }

      final now = DateTime.now();
      final salt = _pinHasher.generateSalt();
      final hash = _pinHasher.hashPin(pin: pin, salt: salt);

      final normalizedEmail = email.trim().toLowerCase();
      final user = LocalUserProfilesCompanion.insert(
        id: _uuid.v4(),
        displayName: displayName.trim(),
        email: normalizedEmail,
        roleId: DefaultAccessRoles.adminId,
        pinSalt: Value(salt),
        pinHash: Value(hash),
        isPosUser: const Value(false),
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
      );

      final inserted = await _database.transaction(() async {
        await _database.into(_database.localUserProfiles).insert(user);
        return (_database.select(_database.localUserProfiles)
              ..where((row) => row.email.equals(normalizedEmail))
              ..limit(1))
            .getSingle();
      });

      return AppSuccess(_setCurrentSession(inserted));
    } on Object catch (error) {
      return _failure(
        'auth_initial_admin_failed',
        'No se pudo crear el administrador inicial.',
        error,
      );
    }
  }

  @override
  Future<AppResult<AuthSession>> signInWithGoogle() async {
    return const AppFailureResult(
      AppFailure(
        code: 'auth_google_not_configured',
        message: 'Google Auth con Supabase aun no esta configurado.',
      ),
    );
  }

  @override
  Future<AppResult<void>> signOut() async {
    _currentOperatorService.clear();
    return const AppSuccess<void>(null);
  }

  AuthSession _setCurrentSession(LocalUserProfile user) {
    final session = AuthSession(
      userId: user.id,
      email: user.email,
      roleId: user.roleId,
      isPosUser: user.isPosUser,
      displayName: user.displayName,
    );
    CurrentOperatorService.currentSession = session;
    return session;
  }

  AppFailureResult<AuthSession> _invalidCredentials() {
    return const AppFailureResult(
      AppFailure(
        code: 'auth_invalid_credentials',
        message: 'Correo o PIN incorrecto.',
      ),
    );
  }

  AppFailureResult<T> _failure<T>(
    String code,
    String message,
    Object? error,
  ) {
    return AppFailureResult(
      AppFailure(code: code, message: message, cause: error),
    );
  }
}
