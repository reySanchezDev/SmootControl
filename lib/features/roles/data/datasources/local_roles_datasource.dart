import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/roles/data/models/access_permission_model.dart';
import 'package:smoo_control/features/roles/data/models/access_role_model.dart';

/// Local datasource for roles and permissions.
final class LocalRolesDataSource {
  /// Creates a local roles datasource.
  const LocalRolesDataSource(this._database);

  final AppDatabase _database;

  /// Returns local roles.
  Future<List<AccessRoleModel>> getRoles() async {
    final query = _database.select(_database.localRoles)
      ..orderBy([(role) => OrderingTerm.asc(role.name)]);
    final rows = await query.get();

    return rows.map(AccessRoleModel.fromLocal).toList();
  }

  /// Saves a role.
  Future<AccessRoleModel> saveRole(AccessRoleModel role) async {
    final now = DateTime.now();
    await _database
        .into(_database.localRoles)
        .insertOnConflictUpdate(
          LocalRolesCompanion(
            id: Value(role.id),
            name: Value(role.name),
            description: Value(role.description),
            isSystem: Value(role.isSystem),
            isActive: Value(role.isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return role;
  }

  /// Returns local permissions.
  Future<List<AccessPermissionModel>> getPermissions() async {
    final query = _database.select(_database.localPermissions)
      ..orderBy([(permission) => OrderingTerm.asc(permission.name)]);
    final rows = await query.get();

    return rows.map(AccessPermissionModel.fromLocal).toList();
  }

  /// Saves a permission.
  Future<AccessPermissionModel> savePermission(
    AccessPermissionModel permission,
  ) async {
    final now = DateTime.now();
    await _database
        .into(_database.localPermissions)
        .insertOnConflictUpdate(
          LocalPermissionsCompanion(
            code: Value(permission.code),
            name: Value(permission.name),
            description: Value(permission.description),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return permission;
  }

  /// Replaces role permission assignments.
  Future<void> setRolePermissions({
    required String roleId,
    required List<String> permissionCodes,
  }) async {
    final now = DateTime.now();
    await _database.batch((batch) {
      batch.deleteWhere(
        _database.localRolePermissions,
        (assignment) => assignment.roleId.equals(roleId),
      );
      for (final code in permissionCodes) {
        batch.insert(
          _database.localRolePermissions,
          LocalRolePermissionsCompanion(
            id: Value('$roleId:$code'),
            roleId: Value(roleId),
            permissionCode: Value(code),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Returns permission codes assigned to a role.
  Future<List<String>> getPermissionCodesForRole(String roleId) async {
    final query = _database.select(_database.localRolePermissions)
      ..where((assignment) => assignment.roleId.equals(roleId))
      ..orderBy([(assignment) => OrderingTerm.asc(assignment.permissionCode)]);
    final rows = await query.get();

    return rows.map((row) => row.permissionCode).toList();
  }
}
