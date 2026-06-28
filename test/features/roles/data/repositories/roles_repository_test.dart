import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/roles/data/datasources/local_roles_datasource.dart';
import 'package:smoo_control/features/roles/data/repositories/roles_repository.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';

void main() {
  group('RolesRepository', () {
    late AppDatabase database;
    late RolesRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = RolesRepository(
        LocalRolesDataSource(database),
        syncQueueRepository: syncQueueRepository,
      );
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
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(roleResult, isA<AppSuccess<AccessRole>>());
      expect(permissionResult, isA<AppSuccess<AccessPermission>>());
      final syncItems = (syncResult as AppSuccess<List<SyncQueueItem>>).value;
      expect(syncItems.map((item) => item.entityType), [
        'roles',
        'permissions',
      ]);

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
      final syncResult = await syncQueueRepository.getPendingItems();
      final syncItems = (syncResult as AppSuccess<List<SyncQueueItem>>).value;

      expect(
        (result as AppSuccess<List<String>>).value,
        ['reportes.ver'],
      );
      expect(syncItems, hasLength(2));
      expect(syncItems.last.entityType, 'role_permissions');
      expect(syncItems.last.operation, SyncOperation.update);
    });
  });
}
