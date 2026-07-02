import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/roles/data/datasources/local_roles_datasource.dart';
import 'package:smoo_control/features/roles/data/models/access_permission_model.dart';
import 'package:smoo_control/features/roles/data/models/access_role_model.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';

/// Roles repository backed by the local offline database.
final class RolesRepository implements IRolesRepository {
  /// Creates a roles repository.
  const RolesRepository(this._localDataSource);

  final LocalRolesDataSource _localDataSource;

  @override
  Future<AppResult<List<AccessPermission>>> getPermissions() async {
    try {
      final permissions = await _localDataSource.getPermissions();
      return AppSuccess(
        permissions.map((permission) => permission.toEntity()).toList(),
      );
    } on Object catch (error) {
      return _failure('permissions_read_failed', 'No se pudieron leer.', error);
    }
  }

  @override
  Future<AppResult<List<String>>> getPermissionCodesForRole(
    String roleId,
  ) async {
    try {
      final codes = await _localDataSource.getPermissionCodesForRole(roleId);
      return AppSuccess(codes);
    } on Object catch (error) {
      return _failure(
        'role_permissions_read_failed',
        'No se pudieron leer.',
        error,
      );
    }
  }

  @override
  Future<AppResult<List<AccessRole>>> getRoles() async {
    try {
      final roles = await _localDataSource.getRoles();
      return AppSuccess(roles.map((role) => role.toEntity()).toList());
    } on Object catch (error) {
      return _failure(
        'roles_read_failed',
        'No se pudieron leer los roles.',
        error,
      );
    }
  }

  @override
  Future<AppResult<AccessPermission>> savePermission(
    AccessPermission permission,
  ) async {
    try {
      final model = AccessPermissionModel.fromEntity(permission);
      final saved = await _localDataSource.savePermission(model);
      final entity = saved.toEntity();

      return AppSuccess(entity);
    } on Object catch (error) {
      return _failure('permission_save_failed', 'No se pudo guardar.', error);
    }
  }

  @override
  Future<AppResult<AccessRole>> saveRole(AccessRole role) async {
    try {
      final model = AccessRoleModel.fromEntity(role);
      final saved = await _localDataSource.saveRole(model);
      final entity = saved.toEntity();

      return AppSuccess(entity);
    } on Object catch (error) {
      return _failure('role_save_failed', 'No se pudo guardar el rol.', error);
    }
  }

  @override
  Future<AppResult<void>> setRolePermissions({
    required String roleId,
    required List<String> permissionCodes,
  }) async {
    try {
      await _localDataSource.setRolePermissions(
        roleId: roleId,
        permissionCodes: permissionCodes,
      );
      return const AppSuccess<void>(null);
    } on Object catch (error) {
      return _failure(
        'role_permissions_save_failed',
        'No se pudieron guardar.',
        error,
      );
    }
  }

  AppFailureResult<T> _failure<T>(
    String code,
    String message,
    Object error,
  ) {
    return AppFailureResult(
      AppFailure(code: code, message: message, cause: error),
    );
  }
}
