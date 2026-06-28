import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';

/// Checks permissions assigned to roles.
final class AccessControlService {
  /// Creates an access control service.
  const AccessControlService(this._rolesRepository);

  final IRolesRepository _rolesRepository;

  /// Returns whether a role has one permission.
  Future<AppResult<bool>> hasPermission({
    required String roleId,
    required String permissionCode,
  }) async {
    final result = await _rolesRepository.getPermissionCodesForRole(roleId);

    return result.when(
      success: (codes) => AppSuccess(codes.contains(permissionCode)),
      failure: AppFailureResult.new,
    );
  }

  /// Returns whether a role has every requested permission.
  Future<AppResult<bool>> hasAllPermissions({
    required String roleId,
    required List<String> permissionCodes,
  }) async {
    final result = await _rolesRepository.getPermissionCodesForRole(roleId);

    return result.when(
      success: (codes) {
        final assigned = codes.toSet();
        return AppSuccess(assigned.containsAll(permissionCodes));
      },
      failure: AppFailureResult.new,
    );
  }

  /// Returns whether a role has at least one requested permission.
  Future<AppResult<bool>> hasAnyPermission({
    required String roleId,
    required List<String> permissionCodes,
  }) async {
    final result = await _rolesRepository.getPermissionCodesForRole(roleId);

    return result.when(
      success: (codes) {
        final assigned = codes.toSet();
        return AppSuccess(permissionCodes.any(assigned.contains));
      },
      failure: AppFailureResult.new,
    );
  }
}
