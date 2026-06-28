import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/roles/domain/services/access_seed_service.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_permissions.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';

void main() {
  group('AccessSeedService', () {
    test('creates default roles, permissions and assignments', () async {
      final repository = _RolesRepositoryFake();
      final service = AccessSeedService(repository);

      final result = await service.ensureSeeded();

      expect(result, isA<AppSuccess<void>>());
      expect(
        repository.permissions,
        hasLength(DefaultAccessPermissions.values.length),
      );
      expect(repository.roles, DefaultAccessRoles.values);
      expect(repository.codesByRole[DefaultAccessRoles.adminId], isNotEmpty);
    });
  });
}

final class _RolesRepositoryFake implements IRolesRepository {
  final List<AccessPermission> permissions = [];
  final List<AccessRole> roles = [];
  final Map<String, List<String>> codesByRole = {};

  @override
  Future<AppResult<List<AccessPermission>>> getPermissions() async {
    return AppSuccess([...permissions]);
  }

  @override
  Future<AppResult<List<String>>> getPermissionCodesForRole(
    String roleId,
  ) async {
    return AppSuccess(codesByRole[roleId] ?? const []);
  }

  @override
  Future<AppResult<List<AccessRole>>> getRoles() async {
    return AppSuccess([...roles]);
  }

  @override
  Future<AppResult<AccessPermission>> savePermission(
    AccessPermission permission,
  ) async {
    permissions.add(permission);
    return AppSuccess(permission);
  }

  @override
  Future<AppResult<AccessRole>> saveRole(AccessRole role) async {
    roles.add(role);
    return AppSuccess(role);
  }

  @override
  Future<AppResult<void>> setRolePermissions({
    required String roleId,
    required List<String> permissionCodes,
  }) async {
    codesByRole[roleId] = permissionCodes;
    return const AppSuccess<void>(null);
  }
}
