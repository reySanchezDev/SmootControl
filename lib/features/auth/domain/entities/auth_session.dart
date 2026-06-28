import 'package:equatable/equatable.dart';

/// Authenticated user session.
final class AuthSession extends Equatable {
  /// Creates an auth session.
  const AuthSession({
    required this.userId,
    required this.email,
    required this.roleId,
    required this.isPosUser,
    this.displayName,
  });

  /// Auth provider user id.
  final String userId;

  /// User email.
  final String email;

  /// Assigned access role.
  final String roleId;

  /// Whether the user enters the POS operational flow directly.
  final bool isPosUser;

  /// Visible display name.
  final String? displayName;

  @override
  List<Object?> get props {
    return [userId, email, roleId, isPosUser, displayName];
  }
}
