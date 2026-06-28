import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_state.dart';

/// BLoC for authentication.
final class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Creates an auth BLoC.
  AuthBloc(this._repository) : super(const AuthInitial()) {
    on<AuthSessionRequested>(_onSessionRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthPinSignInRequested>(_onPinSignInRequested);
    on<AuthInitialAdminCreated>(_onInitialAdminCreated);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final IAuthRepository _repository;

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
        final setupResult = await _repository.isInitialSetupRequired();
        emit(
          setupResult.when(
            success: (required) {
              if (required) return const AuthInitialSetupRequired();
              return const Unauthenticated();
            },
            failure: AuthFailure.new,
          ),
        );
    }
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
    final result = await _repository.signOut();
    emit(
      result.when(
        success: (_) => const Unauthenticated(),
        failure: AuthFailure.new,
      ),
    );
  }
}
