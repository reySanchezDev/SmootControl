import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/core/session/current_remote_session_service.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';
import 'package:smoo_control/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:smoo_control/features/auth/domain/services/device_initialization_service.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_state.dart';

/// BLoC for authentication.
final class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Creates an auth BLoC.
  AuthBloc(
    this._repository, {
    DeviceInitializationService? deviceInitializationService,
    CurrentRemoteSessionService? remoteSessionService,
  }) : _deviceInitializationService = deviceInitializationService,
       _remoteSessionService = remoteSessionService,
       super(const AuthInitial()) {
    on<AuthSessionRequested>(_onSessionRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthPinSignInRequested>(_onPinSignInRequested);
    on<AuthRemoteAdminSignInRequested>(_onRemoteAdminSignInRequested);
    on<AuthInitialAdminCreated>(_onInitialAdminCreated);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final IAuthRepository _repository;
  final DeviceInitializationService? _deviceInitializationService;
  final CurrentRemoteSessionService? _remoteSessionService;

  Future<void> _onSessionRequested(
    AuthSessionRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _repository.getCurrentSession();
    switch (result) {
      case AppFailureResult(:final error):
        emit(AuthFailure(error));
      case AppSuccess(:final value):
        if (value != null) {
          emit(Authenticated(value));
          return;
        }
        final setupResult = await _startupMode();
        emit(
          setupResult.when(
            success: (mode) {
              return switch (mode) {
                DeviceStartupMode.localLogin => const Unauthenticated(),
                DeviceStartupMode.remoteInitialization =>
                  const AuthDeviceInitializationRequired(),
                DeviceStartupMode.remoteInitialSetup =>
                  const AuthRemoteInitialSetupRequired(),
                DeviceStartupMode.localInitialSetup =>
                  const AuthInitialSetupRequired(),
              };
            },
            failure: AuthFailure.new,
          ),
        );
    }
  }

  Future<AppResult<DeviceStartupMode>> _startupMode() async {
    final service = _deviceInitializationService;
    if (service != null) return service.getStartupMode();

    final setupResult = await _repository.isInitialSetupRequired();
    return setupResult.when(
      success: (required) => AppSuccess(
        required
            ? DeviceStartupMode.localInitialSetup
            : DeviceStartupMode.localLogin,
      ),
      failure: AppFailureResult.new,
    );
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _repository.signInWithGoogle();
    emit(
      switch (result) {
        AppSuccess(:final value) => Authenticated(value),
        AppFailureResult(:final error) => AuthFailure(error),
      },
    );
  }

  Future<void> _onPinSignInRequested(
    AuthPinSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _repository.signInWithPin(
      email: event.email,
      pin: event.pin,
    );
    emit(
      switch (result) {
        AppSuccess(:final value) => Authenticated(value),
        AppFailureResult(:final error) => AuthFailure(error),
      },
    );
  }

  Future<void> _onRemoteAdminSignInRequested(
    AuthRemoteAdminSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final service = _deviceInitializationService;
    if (service == null) {
      emit(
        const AuthFailure(
          AppFailure(
            code: 'auth_remote_admin_unavailable',
            message: 'El login remoto de administrador no esta configurado.',
          ),
        ),
      );
      return;
    }

    emit(const AuthLoading());
    final result = await service.signInRemoteAdmin(
      email: event.email,
      password: event.password,
    );
    emit(
      switch (result) {
        AppSuccess(:final value) => Authenticated(
          _setRemoteAdminSession(
            userId: value.userId,
            email: value.email,
            roleId: value.roleId,
            displayName: value.displayName,
          ),
        ),
        AppFailureResult(:final error) => AuthFailure(error),
      },
    );
  }

  Future<void> _onInitialAdminCreated(
    AuthInitialAdminCreated event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _repository.createInitialAdmin(
      displayName: event.displayName,
      email: event.email,
      pin: event.pin,
    );
    emit(
      switch (result) {
        AppSuccess(:final value) => Authenticated(value),
        AppFailureResult(:final error) => AuthFailure(
          error,
          setupRequired: true,
        ),
      },
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    _remoteSessionService?.clear();
    final result = await _repository.signOut();
    emit(
      result.when(
        success: (_) => const Unauthenticated(),
        failure: AuthFailure.new,
      ),
    );
  }

  AuthSession _setRemoteAdminSession({
    required String userId,
    required String email,
    required String roleId,
    required String displayName,
  }) {
    final session = AuthSession(
      userId: userId,
      email: email,
      roleId: roleId,
      isPosUser: false,
      displayName: displayName,
    );
    CurrentOperatorService.currentSession = session;
    return session;
  }
}
