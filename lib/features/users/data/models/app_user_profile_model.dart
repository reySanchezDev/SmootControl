import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';

/// Data model for a local user profile row.
final class AppUserProfileModel extends Equatable {
  /// Creates a user profile model.
  const AppUserProfileModel({
    required this.id,
    required this.displayName,
    required this.email,
    required this.roleId,
    required this.isActive,
    required this.isPosUser,
    this.pinSalt,
    this.pinHash,
  });

  /// Creates a model from a local row.
  factory AppUserProfileModel.fromLocal(LocalUserProfile row) {
    return AppUserProfileModel(
      id: row.id,
      displayName: row.displayName,
      email: row.email,
      roleId: row.roleId,
      pinSalt: row.pinSalt,
      pinHash: row.pinHash,
      isPosUser: row.isPosUser,
      isActive: row.isActive,
    );
  }

  /// Creates a model from a domain entity.
  factory AppUserProfileModel.fromEntity(AppUserProfile entity) {
    return AppUserProfileModel(
      id: entity.id,
      displayName: entity.displayName,
      email: entity.email,
      roleId: entity.roleId,
      pinSalt: entity.pinSalt,
      pinHash: entity.pinHash,
      isPosUser: entity.isPosUser,
      isActive: entity.isActive,
    );
  }

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

  /// Whether the user can access the app.
  final bool isActive;

  /// Converts this model to a domain entity.
  AppUserProfile toEntity() {
    return AppUserProfile(
      id: id,
      displayName: displayName,
      email: email,
      roleId: roleId,
      pinSalt: pinSalt,
      pinHash: pinHash,
      isPosUser: isPosUser,
      isActive: isActive,
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
