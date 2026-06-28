import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';

/// Data model for a role row.
final class AccessRoleModel extends Equatable {
  /// Creates a role model.
  const AccessRoleModel({
    required this.id,
    required this.name,
    required this.isSystem,
    required this.isActive,
    this.description,
  });

  /// Creates a model from a local row.
  factory AccessRoleModel.fromLocal(LocalRole row) {
    return AccessRoleModel(
      id: row.id,
      name: row.name,
      description: row.description,
      isSystem: row.isSystem,
      isActive: row.isActive,
    );
  }

  /// Creates a model from a domain entity.
  factory AccessRoleModel.fromEntity(AccessRole entity) {
    return AccessRoleModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      isSystem: entity.isSystem,
      isActive: entity.isActive,
    );
  }

  /// Local identifier.
  final String id;

  /// Visible name.
  final String name;

  /// Optional description.
  final String? description;

  /// Whether this role is protected.
  final bool isSystem;

  /// Whether this role can be assigned.
  final bool isActive;

  /// Converts this model to a domain entity.
  AccessRole toEntity() {
    return AccessRole(
      id: id,
      name: name,
      description: description,
      isSystem: isSystem,
      isActive: isActive,
    );
  }

  @override
  List<Object?> get props => [id, name, description, isSystem, isActive];
}
