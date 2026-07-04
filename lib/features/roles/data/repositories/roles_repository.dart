import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/roles/data/datasources/local_roles_datasource.dart';
import 'package:smoo_control/features/roles/data/models/access_permission_model.dart';
import 'package:smoo_control/features/roles/data/models/access_role_model.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/domain/repositories/i_roles_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

/// Roles repository backed by the local offline database.
final class RolesRepository implements IRolesRepository {
  /// Creates a roles repository.
  const RolesRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    ISyncRemoteSender? remoteSender,
  }) : _syncQueueRepository = syncQueueRepository,
       _remoteSender = remoteSender;

  final LocalRolesDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final ISyncRemoteSender? _remoteSender;

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
      await _pushRemote(
        entityType: 'permissions',
        entityId: permission.code,
        payload: _permissionPayload(permission),
      );
      final saved = await _localDataSource.savePermission(model);
      final entity = saved.toEntity();
      if (_remoteSender == null) {
        await _syncQueueRepository?.enqueue(
          entityType: 'permissions',
          entityId: entity.code,
          operation: SyncOperation.create,
          payload: _permissionPayload(entity),
        );
      }

      return AppSuccess(entity);
    } on Object catch (error) {
      return _failure('permission_save_failed', 'No se pudo guardar.', error);
    }
  }

  @override
  Future<AppResult<AccessRole>> saveRole(AccessRole role) async {
    try {
      final model = AccessRoleModel.fromEntity(role);
      await _pushRemote(
        entityType: 'roles',
        entityId: role.id,
        payload: _rolePayload(role),
      );
      final saved = await _localDataSource.saveRole(model);
      final entity = saved.toEntity();
      if (_remoteSender == null) {
        await _syncQueueRepository?.enqueue(
          entityType: 'roles',
          entityId: entity.id,
          operation: SyncOperation.create,
          payload: _rolePayload(entity),
        );
      }

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
      final normalizedCodes = permissionCodes.toSet().toList()..sort();
      await _pushRemote(
        entityType: 'role_permissions',
        entityId: roleId,
        payload: {
          'roleId': roleId,
          'permissionCodes': normalizedCodes,
        },
      );
      await _localDataSource.setRolePermissions(
        roleId: roleId,
        permissionCodes: normalizedCodes,
      );
      if (_remoteSender == null) {
        await _syncQueueRepository?.enqueue(
          entityType: 'role_permissions',
          entityId: roleId,
          operation: SyncOperation.update,
          payload: {
            'roleId': roleId,
            'permissionCodes': normalizedCodes,
          },
        );
      }
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

  Map<String, Object?> _permissionPayload(AccessPermission permission) {
    return {
      'code': permission.code,
      'name': permission.name,
      'description': permission.description,
    };
  }

  Map<String, Object?> _rolePayload(AccessRole role) {
    return {
      'id': role.id,
      'name': role.name,
      'description': role.description,
      'isSystem': role.isSystem,
      'isActive': role.isActive,
    };
  }

  Future<void> _pushRemote({
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    final remoteSender = _remoteSender;
    if (remoteSender == null) return;

    final now = DateTime.now();
    await remoteSender.push(
      SyncQueueItem(
        id: 'admin-direct-$entityType-$entityId',
        entityType: entityType,
        entityId: entityId,
        operation: SyncOperation.create,
        payload: payload,
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
