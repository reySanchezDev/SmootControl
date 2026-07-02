import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/roles/data/datasources/local_roles_datasource.dart';
import 'package:smoo_control/features/roles/data/repositories/roles_repository.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';

void main() {
  group('RolesRepository', () {
    late AppDatabase database;
    late RolesRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = RolesRepository(LocalRolesDataSource(database));
    });

    tearDown(() async {
      await database.close();
    });

    test('saves roles and permissions locally', () async {
      const role = AccessRole(
        id: 'role-admin',
        name: 'Administrador',
        description: 'Control total',
        isSystem: true,
        isActive: true,
      );
      const permission = AccessPermission(
        code: 'gastos.crear',
        name: 'Crear gastos',
      );

      final roleResult = await repository.saveRole(role);
      final permissionResult = await repository.savePermission(permission);

      expect(roleResult, isA<AppSuccess<AccessRole>>());
      expect(permissionResult, isA<AppSuccess<AccessPermission>>());

      final rolesResult = await repository.getRoles();
      final permissionsResult = await repository.getPermissions();

      expect((rolesResult as AppSuccess<List<AccessRole>>).value, [role]);
      expect(
        (permissionsResult as AppSuccess<List<AccessPermission>>).value,
        [permission],
      );
    });

    test('replaces permissions assigned to a role', () async {
      await repository.setRolePermissions(
        roleId: 'role-admin',
        permissionCodes: const ['ventas.anular', 'gastos.crear'],
      );
      await repository.setRolePermissions(
        roleId: 'role-admin',
        permissionCodes: const ['reportes.ver'],
      );

      final result = await repository.getPermissionCodesForRole('role-admin');

      expect(
        (result as AppSuccess<List<String>>).value,
        ['reportes.ver'],
      );
    });
  });
}
