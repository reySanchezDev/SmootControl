import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';

/// Contract for authentication.
abstract interface class IAuthRepository {
  /// Returns the current authenticated session, if any.
  Future<AppResult<AuthSession?>> getCurrentSession();

  /// Returns whether the app needs the first local administrator.
  Future<AppResult<bool>> isInitialSetupRequired();

  /// Signs in one local user with email and PIN.
  Future<AppResult<AuthSession>> signInWithPin({
    required String email,
    required String pin,
  });

  /// Creates the first local administrator when no user with PIN exists.
  Future<AppResult<AuthSession>> createInitialAdmin({
    required String displayName,
    required String email,
    required String pin,
  });

  /// Starts Google sign-in.
  Future<AppResult<AuthSession>> signInWithGoogle();

  /// Signs out the current user.
  Future<AppResult<void>> signOut();
}
