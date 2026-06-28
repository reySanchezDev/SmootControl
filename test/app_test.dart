import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/app/smoo_control_app.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';
import 'package:smoo_control/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  tearDown(serviceLocator.reset);

  testWidgets('renders the login gate before the dashboard', (tester) async {
    serviceLocator.registerFactory<AuthBloc>(
      () => AuthBloc(const _AuthRepositoryFake()),
    );

    await tester.pumpWidget(const SmooControlApp());
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesion'), findsOneWidget);
    expect(find.text('Panel operativo'), findsNothing);
  });
}

final class _AuthRepositoryFake implements IAuthRepository {
  const _AuthRepositoryFake();

  @override
  Future<AppResult<AuthSession?>> getCurrentSession() async {
    return const AppSuccess(null);
  }

  @override
  Future<AppResult<bool>> isInitialSetupRequired() async {
    return const AppSuccess(false);
  }

  @override
  Future<AppResult<AuthSession>> createInitialAdmin({
    required String displayName,
    required String email,
    required String pin,
  }) async {
    return const AppFailureResult(
      AppFailure(code: 'auth_not_configured', message: 'Pendiente'),
    );
  }

  @override
  Future<AppResult<AuthSession>> signInWithGoogle() async {
    return const AppFailureResult(
      AppFailure(code: 'auth_not_configured', message: 'Pendiente'),
    );
  }

  @override
  Future<AppResult<AuthSession>> signInWithPin({
    required String email,
    required String pin,
  }) async {
    return const AppFailureResult(
      AppFailure(code: 'auth_not_configured', message: 'Pendiente'),
    );
  }

  @override
  Future<AppResult<void>> signOut() async {
    return const AppSuccess<void>(null);
  }
}
