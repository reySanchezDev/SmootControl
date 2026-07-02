import 'package:equatable/equatable.dart';

/// Remote administrator authenticated for device initialization.
final class RemoteBootstrapSession extends Equatable {
  /// Creates a remote bootstrap session.
  const RemoteBootstrapSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
    required this.email,
    required this.displayName,
    required this.roleId,
    required this.restaurantId,
    required this.hasLocalPin,
  });

  /// Supabase access token. It must remain in memory only.
  final String accessToken;

  /// Supabase refresh token persisted locally for device sync renewal.
  final String refreshToken;

  /// Access token expiration.
  final DateTime expiresAt;

  /// Remote profile id.
  final String userId;

  /// Remote email.
  final String email;

  /// Remote display name.
  final String displayName;

  /// Remote role id.
  final String roleId;

  /// Restaurant id.
  final String restaurantId;

  /// Whether the remote profile already has PIN hash data.
  final bool hasLocalPin;

  /// Returns a copy with an initialized local PIN flag.
  RemoteBootstrapSession withLocalPin() {
    return RemoteBootstrapSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      userId: userId,
      email: email,
      displayName: displayName,
      roleId: roleId,
      restaurantId: restaurantId,
      hasLocalPin: true,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    refreshToken,
    expiresAt,
    email,
    displayName,
    roleId,
    restaurantId,
    hasLocalPin,
  ];
}
