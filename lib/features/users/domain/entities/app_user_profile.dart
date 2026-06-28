import 'package:equatable/equatable.dart';

/// Local app user profile mapped to a role.
final class AppUserProfile extends Equatable {
  /// Creates an app user profile.
  const AppUserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.roleId,
    required this.isActive,
    required this.isPosUser,
    this.pinSalt,
    this.pinHash,
  });

  /// Local or auth provider identifier.
  final String id;

  /// Visible display name.
  final String displayName;

  /// User email.
  final String email;

  /// Assigned role identifier.
  final String roleId;

  /// Salt used to validate the local access PIN.
  final String? pinSalt;

  /// Hash used to validate the local access PIN.
  final String? pinHash;

  /// Whether the user enters the POS operational flow directly.
  final bool isPosUser;

  /// Whether this user can access the app.
  final bool isActive;

  /// Whether this user can sign in with a local PIN.
  bool get hasLocalPin => pinSalt != null && pinHash != null;

  /// Creates a copy with selected fields changed.
  AppUserProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? roleId,
    String? pinSalt,
    String? pinHash,
    bool? isPosUser,
    bool? isActive,
  }) {
    return AppUserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      roleId: roleId ?? this.roleId,
      pinSalt: pinSalt ?? this.pinSalt,
      pinHash: pinHash ?? this.pinHash,
      isPosUser: isPosUser ?? this.isPosUser,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props {
    return [
      id,
      displayName,
      email,
      roleId,
      pinSalt,
      pinHash,
      isPosUser,
      isActive,
    ];
  }
}
