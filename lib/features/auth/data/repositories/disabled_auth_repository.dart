import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';
import 'package:smoo_control/features/auth/domain/repositories/i_auth_repository.dart';

/// Auth repository used until Supabase Google Auth is configured.
final class DisabledAuthRepository implements IAuthRepository {
  /// Creates a disabled auth repository.
  const DisabledAuthRepository();

  @override
  Future<AppResult<AuthSession?>> getCurrentSession() async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<bool>> isInitialSetupRequired() async {
    return const AppSuccess(false);
  }

  @override
  Future<AppResult<AuthSession>> signInWithPin({
    required String email,
    required String pin,
  }) async {
    return const AppFailureResult(
      AppFailure(
        code: 'auth_not_configured',
        message: 'Auth local aun no esta configurado.',
      ),
    );
  }

  @override
  Future<AppResult<AuthSession>> createInitialAdmin({
    required String displayName,
    required String email,
    required String pin,
  }) async {
    return const AppFailureResult(
      AppFailure(
        code: 'auth_not_configured',
        message: 'Auth local aun no esta configurado.',
      ),
    );
  }

  @override
  Future<AppResult<AuthSession>> signInWithGoogle() async {
    return const AppFailureResult(
      AppFailure(
        code: 'auth_not_configured',
        message: 'Google Auth con Supabase aun no esta configurado.',
      ),
    );
  }

  @override
  Future<AppResult<void>> signOut() async {
    return const AppSuccess<void>(null);
  }
}
