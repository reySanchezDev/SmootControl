import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoo_control/core/app/smoo_control_app.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';
import 'package:smoo_control/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  tearDown(serviceLocator.reset);

  testWidgets('renders the login gate before the dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    serviceLocator.registerFactory<AuthBloc>(
      () => AuthBloc(const _AuthRepositoryFake()),
    );
    _registerRemoteSession();

    await tester.pumpWidget(const SmooControlApp());
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesion'), findsOneWidget);
    expect(find.text('Panel operativo'), findsNothing);
  });

  testWidgets('prefills remembered POS email and can update it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'auth.remember_pos_email': true,
      'auth.remembered_pos_email': 'mesero@smoo.test',
    });
    serviceLocator.registerFactory<AuthBloc>(
      () => AuthBloc(const _AuthRepositoryFake()),
    );
    _registerRemoteSession();

    await tester.pumpWidget(const SmooControlApp());
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextField>(find.byType(TextField).first);
    expect(emailField.controller?.text, 'mesero@smoo.test');

    await tester.enterText(find.byType(TextField).first, 'nuevo@smoo.test');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('auth.remember_pos_email'), isTrue);
    expect(
      preferences.getString('auth.remembered_pos_email'),
      'nuevo@smoo.test',
    );
  });
}

void _registerRemoteSession() {
  serviceLocator.registerLazySingleton(CurrentRemoteSessionService.new);
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
