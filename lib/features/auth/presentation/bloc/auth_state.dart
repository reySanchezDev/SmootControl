import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/auth/domain/entities/auth_session.dart';

/// Base authentication state.
sealed class AuthState extends Equatable {
  /// Creates an auth state.
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial auth state.
final class AuthInitial extends AuthState {
  /// Creates initial state.
  const AuthInitial();
}

/// Loading auth state.
final class AuthLoading extends AuthState {
  /// Creates loading state.
  const AuthLoading();
}

/// Authenticated state.
final class Authenticated extends AuthState {
  /// Creates authenticated state.
  const Authenticated(this.session);

  /// Current session.
  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

/// Unauthenticated state.
final class Unauthenticated extends AuthState {
  /// Creates unauthenticated state.
  const Unauthenticated();
}

/// State used when the first local administrator must be created.
final class AuthInitialSetupRequired extends AuthState {
  /// Creates initial setup required state.
  const AuthInitialSetupRequired();
}

/// Auth failure state.
final class AuthFailure extends AuthState {
  /// Creates failure state.
  const AuthFailure(this.failure, {this.setupRequired = false});

  /// Failure details.
  final AppFailure failure;

  /// Whether the login view should stay in initial setup mode.
  final bool setupRequired;

  @override
  List<Object?> get props => [failure, setupRequired];
}
