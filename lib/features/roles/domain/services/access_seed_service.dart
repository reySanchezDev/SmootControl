import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_permissions.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';
import 'package:smoo_control/features/roles/domain/services/default_role_permissions.dart';

/// Ensures default roles and permissions exist locally.
final class AccessSeedService {
  /// Creates an access seed service.
  const AccessSeedService(this._rolesRepository);

  final IRolesRepository _rolesRepository;

  /// Creates default permissions, roles and assignments when missing.
  Future<AppResult<void>> ensureSeeded() async {
    final permissionsResult = await _rolesRepository.getPermissions();
    if (permissionsResult case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (permissionsResult case AppSuccess(:final value)) {
      final existingCodes = value.map((permission) => permission.code).toSet();
      final missingPermissions = DefaultAccessPermissions.values.where(
        (permission) => !existingCodes.contains(permission.code),
      );
      for (final permission in missingPermissions) {
        final result = await _rolesRepository.savePermission(permission);
        if (result case AppFailureResult(:final error)) {
          return AppFailureResult(error);
        }
      }
    }

    final rolesResult = await _rolesRepository.getRoles();
    if (rolesResult case AppFailureResult(:final error)) {
      return AppFailureResult(error);
    }
    if (rolesResult case AppSuccess(:final value) when value.isEmpty) {
      for (final role in DefaultAccessRoles.values) {
        final result = await _rolesRepository.saveRole(role);
        if (result case AppFailureResult(:final error)) {
          return AppFailureResult(error);
        }
        final permissions = DefaultRolePermissions.values[role.id] ?? const [];
        final assignmentResult = await _rolesRepository.setRolePermissions(
          roleId: role.id,
          permissionCodes: permissions,
        );
        if (assignmentResult case AppFailureResult(:final error)) {
          return AppFailureResult(error);
        }
      }
    }
    final adminPermissionResult = await _rolesRepository
        .getPermissionCodesForRole(
          DefaultAccessRoles.adminId,
        );
    if (adminPermissionResult case AppSuccess(:final value)) {
      final expected =
          DefaultRolePermissions.values[DefaultAccessRoles.adminId] ??
          const <String>[];
      final merged = {...value, ...expected}.toList()..sort();
      if (merged.length != value.toSet().length) {
        final result = await _rolesRepository.setRolePermissions(
          roleId: DefaultAccessRoles.adminId,
          permissionCodes: merged,
        );
        if (result case AppFailureResult(:final error)) {
          return AppFailureResult(error);
        }
      }
    }

    return const AppSuccess<void>(null);
  }
}
