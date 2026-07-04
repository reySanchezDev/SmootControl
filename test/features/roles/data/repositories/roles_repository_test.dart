import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/roles/data/datasources/local_roles_datasource.dart';
import 'package:smoo_control/features/roles/data/repositories/roles_repository.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

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

    test(
      'pushes role permission changes to Supabase before local cache',
      () async {
        final remoteSender = _RemoteSenderFake();
        repository = RolesRepository(
          LocalRolesDataSource(database),
          remoteSender: remoteSender,
        );

        final result = await repository.setRolePermissions(
          roleId: 'role-waiter',
          permissionCodes: const [
            'modificadores.disponibilidad',
            'sync.ejecutar',
          ],
        );

        expect(result, isA<AppSuccess<void>>());
        expect(remoteSender.items.single.entityType, 'role_permissions');
        expect(remoteSender.items.single.entityId, 'role-waiter');
        expect(remoteSender.items.single.payload['permissionCodes'], [
          'modificadores.disponibilidad',
          'sync.ejecutar',
        ]);

        final codes = await repository.getPermissionCodesForRole('role-waiter');
        expect((codes as AppSuccess<List<String>>).value, [
          'modificadores.disponibilidad',
          'sync.ejecutar',
        ]);
      },
    );

    test(
      'does not update local permissions when Supabase rejects save',
      () async {
        final remoteSender = _RemoteSenderFake(
          error: StateError('remote rejected'),
        );
        repository = RolesRepository(
          LocalRolesDataSource(database),
          remoteSender: remoteSender,
        );

        final result = await repository.setRolePermissions(
          roleId: 'role-waiter',
          permissionCodes: const ['modificadores.disponibilidad'],
        );

        expect(result, isA<AppFailureResult<void>>());
        final codes = await repository.getPermissionCodesForRole('role-waiter');
        expect((codes as AppSuccess<List<String>>).value, isEmpty);
      },
    );
  });
}

final class _RemoteSenderFake implements ISyncRemoteSender {
  _RemoteSenderFake({this.error});

  final Object? error;
  final List<SyncQueueItem> items = [];

  @override
  Future<void> push(SyncQueueItem item) async {
    final error = this.error;
    if (error is Exception) throw error;
    if (error is Error) throw error;
    if (error != null) throw StateError(error.toString());
    items.add(item);
  }
}
