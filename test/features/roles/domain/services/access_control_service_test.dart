import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/roles/domain/services/access_control_service.dart';

void main() {
  group('AccessControlService', () {
    late AccessControlService service;

    setUp(() {
      service = const AccessControlService(
        _RolesRepositoryFake({
          'role-cashier': ['ventas.registrar', 'cuentas.separar'],
        }),
      );
    });

    test('checks one permission', () async {
      final result = await service.hasPermission(
        roleId: 'role-cashier',
        permissionCode: 'ventas.registrar',
      );

      expect((result as AppSuccess<bool>).value, isTrue);
    });

    test('checks all required permissions', () async {
      final result = await service.hasAllPermissions(
        roleId: 'role-cashier',
        permissionCodes: const ['ventas.registrar', 'cuentas.separar'],
      );

      expect((result as AppSuccess<bool>).value, isTrue);
    });

    test('checks any allowed permission', () async {
      final result = await service.hasAnyPermission(
        roleId: 'role-cashier',
        permissionCodes: const ['reportes.ver', 'cuentas.separar'],
      );

      expect((result as AppSuccess<bool>).value, isTrue);
    });
  });
}

final class _RolesRepositoryFake implements IRolesRepository {
  const _RolesRepositoryFake(this.codesByRole);

  final Map<String, List<String>> codesByRole;

  @override
  Future<AppResult<List<AccessPermission>>> getPermissions() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<String>>> getPermissionCodesForRole(
    String roleId,
  ) async {
    return AppSuccess(codesByRole[roleId] ?? const []);
  }

  @override
  Future<AppResult<List<AccessRole>>> getRoles() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<AccessPermission>> savePermission(
    AccessPermission permission,
  ) async {
    return AppSuccess(permission);
  }

  @override
  Future<AppResult<AccessRole>> saveRole(AccessRole role) async {
    return AppSuccess(role);
  }

  @override
  Future<AppResult<void>> setRolePermissions({
    required String roleId,
    required List<String> permissionCodes,
  }) async {
    return const AppSuccess<void>(null);
  }
}
