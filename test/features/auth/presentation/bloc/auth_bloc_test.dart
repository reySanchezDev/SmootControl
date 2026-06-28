import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';
import 'package:smoo_control/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_state.dart';

void main() {
  group('AuthBloc', () {
    const session = AuthSession(
      userId: 'user-1',
      email: 'rey@example.com',
      roleId: 'role-admin',
      isPosUser: false,
      displayName: 'Rey',
    );

    blocTest<AuthBloc, AuthState>(
      'emits authenticated when session exists',
      build: () => AuthBloc(const _AuthRepositoryFake(currentSession: session)),
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => const [
        AuthLoading(),
        Authenticated(session),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits failure when Google Auth is not configured',
      build: () => AuthBloc(
        const _AuthRepositoryFake(
          signInResult: AppFailureResult(
            AppFailure(code: 'auth_not_configured', message: 'Pendiente'),
          ),
        ),
      ),
      act: (bloc) => bloc.add(const AuthGoogleSignInRequested()),
      expect: () => const [
        AuthLoading(),
        AuthFailure(
          AppFailure(code: 'auth_not_configured', message: 'Pendiente'),
        ),
      ],
    );
  });
}

final class _AuthRepositoryFake implements IAuthRepository {
  const _AuthRepositoryFake({
    this.currentSession,
    this.signInResult,
  });

  final AuthSession? currentSession;
  final AppResult<AuthSession>? signInResult;

  @override
  Future<AppResult<AuthSession?>> getCurrentSession() async {
    return AppSuccess(currentSession);
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
    return signInResult ??
        const AppFailureResult(
          AppFailure(code: 'auth_not_configured', message: 'Pendiente'),
        );
  }

  @override
  Future<AppResult<AuthSession>> createInitialAdmin({
    required String displayName,
    required String email,
    required String pin,
  }) async {
    return signInResult ??
        const AppFailureResult(
          AppFailure(code: 'auth_not_configured', message: 'Pendiente'),
        );
  }

  @override
  Future<AppResult<AuthSession>> signInWithGoogle() async {
    return signInResult ??
        const AppFailureResult(
          AppFailure(code: 'auth_not_configured', message: 'Pendiente'),
        );
  }

  @override
  Future<AppResult<void>> signOut() async {
    return const AppSuccess<void>(null);
  }
}
