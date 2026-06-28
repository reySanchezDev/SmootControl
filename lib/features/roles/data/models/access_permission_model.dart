import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';

/// Data model for a permission row.
final class AccessPermissionModel extends Equatable {
  /// Creates a permission model.
  const AccessPermissionModel({
    required this.code,
    required this.name,
    this.description,
  });

  /// Creates a model from a local row.
  factory AccessPermissionModel.fromLocal(LocalPermission row) {
    return AccessPermissionModel(
      code: row.code,
      name: row.name,
      description: row.description,
    );
  }

  /// Creates a model from a domain entity.
  factory AccessPermissionModel.fromEntity(AccessPermission entity) {
    return AccessPermissionModel(
      code: entity.code,
      name: entity.name,
      description: entity.description,
    );
  }

  /// Stable permission code.
  final String code;

  /// Visible name.
  final String name;

  /// Optional description.
  final String? description;

  /// Converts this model to a domain entity.
  AccessPermission toEntity() {
    return AccessPermission(
      code: code,
      name: name,
      description: description,
    );
  }

  @override
  List<Object?> get props => [code, name, description];
}
