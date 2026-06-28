import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/roles/domain/services/access_seed_service.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_permissions.dart';
import 'package:smoo_control/features/roles/presentation/bloc/roles_bloc.dart';
import 'package:smoo_control/features/roles/presentation/bloc/roles_event.dart';
import 'package:smoo_control/features/roles/presentation/bloc/roles_state.dart';

void main() {
  group('RolesBloc', () {
    const admin = AccessRole(
      id: 'role-admin',
      name: 'Administrador',
      isSystem: true,
      isActive: true,
    );

    blocTest<RolesBloc, RolesState>(
      'loads roles and seeds default permissions when catalog is empty',
      build: () {
        final repository = _RolesRepositoryFake(roles: [admin]);
        return RolesBloc(
          repository: repository,
          seedService: AccessSeedService(repository),
          auditLogRepository: AuditLogRepositoryFake(),
        );
      },
      act: (bloc) => bloc.add(const RolesLoadRequested()),
      expect: () => [
        const RolesLoading(),
        isA<RolesLoaded>()
            .having((state) => state.roles, 'roles', [admin])
            .having(
              (state) => state.permissions.length,
              'permissions',
              DefaultAccessPermissions.values.length,
            ),
      ],
    );

    blocTest<RolesBloc, RolesState>(
      'writes audit log when saving role',
      setUp: () {
        audit = AuditLogRepositoryFake();
      },
      build: () {
        final repository = _RolesRepositoryFake(roles: [admin]);
        return RolesBloc(
          repository: repository,
          seedService: AccessSeedService(repository),
          auditLogRepository: audit,
        );
      },
      act: (bloc) => bloc.add(
        const RoleSaved(
          role: admin,
          permissionCodes: ['ventas.registrar'],
        ),
      ),
      verify: (_) {
        expect(audit.entries.single.action, 'roles.save');
        expect(audit.entries.single.entityId, 'role-admin');
      },
    );
  });
}

late AuditLogRepositoryFake audit;

final class _RolesRepositoryFake implements IRolesRepository {
  _RolesRepositoryFake({required this.roles});

  final List<AccessRole> roles;
  final List<AccessPermission> permissions = [];
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
    return AppSuccess(roles);
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

final class AuditLogRepositoryFake implements IAuditLogRepository {
  final List<AuditLogEntry> entries = [];

  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return AppSuccess(entries);
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    entries.add(entry);
    return AppSuccess(entry);
  }
}
