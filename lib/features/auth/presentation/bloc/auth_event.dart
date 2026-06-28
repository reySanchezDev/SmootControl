import 'package:equatable/equatable.dart';

/// Base event for authentication.
sealed class AuthEvent extends Equatable {
  /// Creates an auth event.
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Requests current session loading.
final class AuthSessionRequested extends AuthEvent {
  /// Creates a session requested event.
  const AuthSessionRequested();
}

/// Requests Google sign-in.
final class AuthGoogleSignInRequested extends AuthEvent {
  /// Creates a Google sign-in event.
  const AuthGoogleSignInRequested();
}

/// Requests local PIN sign-in.
final class AuthPinSignInRequested extends AuthEvent {
  /// Creates a local PIN sign-in event.
  const AuthPinSignInRequested({
    required this.email,
    required this.pin,
  });

  /// User email.
  final String email;

  /// Local access PIN.
  final String pin;

  @override
  List<Object?> get props => [email, pin];
}

/// Requests initial administrator creation.
final class AuthInitialAdminCreated extends AuthEvent {
  /// Creates an initial administrator creation event.
  const AuthInitialAdminCreated({
    required this.displayName,
    required this.email,
    required this.pin,
  });

  /// Administrator display name.
  final String displayName;

  /// Administrator email.
  final String email;

  /// Administrator local access PIN.
  final String pin;

  @override
  List<Object?> get props => [displayName, email, pin];
}

/// Requests sign-out.
final class AuthSignOutRequested extends AuthEvent {
  /// Creates a sign-out event.
  const AuthSignOutRequested();
}
