import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';

/// Contract for roles and permissions.
abstract interface class IRolesRepository {
  /// Returns available roles.
  Future<AppResult<List<AccessRole>>> getRoles();

  /// Saves one role.
  Future<AppResult<AccessRole>> saveRole(AccessRole role);

  /// Returns the permission catalog.
  Future<AppResult<List<AccessPermission>>> getPermissions();

  /// Saves one permission.
  Future<AppResult<AccessPermission>> savePermission(
    AccessPermission permission,
  );

  /// Replaces all permission assignments for a role.
  Future<AppResult<void>> setRolePermissions({
    required String roleId,
    required List<String> permissionCodes,
  });

  /// Returns permission codes assigned to a role.
  Future<AppResult<List<String>>> getPermissionCodesForRole(String roleId);
}
