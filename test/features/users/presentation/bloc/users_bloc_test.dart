import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/audit/domain/entities/audit_log_entry.dart';
import 'package:smoo_control/features/audit/domain/repositories/i_audit_log_repository.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/roles/domain/services/access_seed_service.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';
import 'package:smoo_control/features/users/domain/repositories/i_users_repository.dart';
import 'package:smoo_control/features/users/presentation/bloc/users_bloc.dart';
import 'package:smoo_control/features/users/presentation/bloc/users_event.dart';
import 'package:smoo_control/features/users/presentation/bloc/users_state.dart';

void main() {
  group('UsersBloc', () {
    const role = AccessRole(
      id: 'role-admin',
      name: 'Administrador',
      isSystem: true,
      isActive: true,
    );
    const user = AppUserProfile(
      id: 'user-1',
      displayName: 'Rey',
      email: 'rey@example.com',
      roleId: 'role-admin',
      isPosUser: false,
      isActive: true,
    );

    blocTest<UsersBloc, UsersState>(
      'loads users with assignable roles',
      build: () {
        const rolesRepository = _RolesRepositoryFake([role]);
        return UsersBloc(
          usersRepository: const _UsersRepositoryFake([user]),
          rolesRepository: rolesRepository,
          seedService: const AccessSeedService(rolesRepository),
          auditLogRepository: AuditLogRepositoryFake(),
        );
      },
      act: (bloc) => bloc.add(const UsersLoadRequested()),
      expect: () => const [
        UsersLoading(),
        UsersLoaded(users: [user], roles: [role]),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'writes audit log when saving user',
      setUp: () {
        audit = AuditLogRepositoryFake();
      },
      build: () {
        const rolesRepository = _RolesRepositoryFake([role]);
        return UsersBloc(
          usersRepository: const _UsersRepositoryFake([]),
          rolesRepository: rolesRepository,
          seedService: const AccessSeedService(rolesRepository),
          auditLogRepository: audit,
        );
      },
      act: (bloc) => bloc.add(const UserSaved(user)),
      verify: (_) {
        expect(audit.entries.single.action, 'users.save');
        expect(audit.entries.single.entityId, 'user-1');
      },
    );
  });
}

late AuditLogRepositoryFake audit;

final class _UsersRepositoryFake implements IUsersRepository {
  const _UsersRepositoryFake(this.users);

  final List<AppUserProfile> users;

  @override
  Future<AppResult<List<AppUserProfile>>> getUsers() async {
    return AppSuccess(users);
  }

  @override
  Future<AppResult<AppUserProfile>> saveUser(
    AppUserProfile user, {
    String? pin,
  }) async {
    return AppSuccess(user);
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

final class _RolesRepositoryFake implements IRolesRepository {
  const _RolesRepositoryFake(this.roles);

  final List<AccessRole> roles;

  @override
  Future<AppResult<List<AccessPermission>>> getPermissions() async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<String>>> getPermissionCodesForRole(
    String roleId,
  ) async {
    return const AppSuccess([]);
  }

  @override
  Future<AppResult<List<AccessRole>>> getRoles() async {
    return AppSuccess(roles);
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
