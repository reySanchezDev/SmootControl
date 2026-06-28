import 'package:equatable/equatable.dart';

/// Permission assignment for one role.
final class RolePermissionAssignment extends Equatable {
  /// Creates a role permission assignment.
  const RolePermissionAssignment({
    required this.id,
    required this.roleId,
    required this.permissionCode,
  });

  /// Local assignment identifier.
  final String id;

  /// Role identifier.
  final String roleId;

  /// Permission code.
  final String permissionCode;

  @override
  List<Object?> get props => [id, roleId, permissionCode];
}
