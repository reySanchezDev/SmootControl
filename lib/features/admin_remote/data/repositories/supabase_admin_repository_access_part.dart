part of 'supabase_admin_repository.dart';

mixin _SupabaseAdminAccessMixin on _SupabaseAdminRepositoryBase
    implements IRolesRepository, IUsersRepository, IAuditLogRepository {
  @override
  Future<AppResult<List<AccessRole>>> getRoles() async {
    return _guard('roles_read_failed', 'No se pudieron leer roles.', () async {
      final rows = await _getRows('roles', {
        'or': '(restaurant_id.eq.$_restaurantId,restaurant_id.is.null)',
        'select': 'id,name,description,is_system,is_active',
        'order': 'name.asc',
      });
      return rows
          .map(
            (row) => AccessRole(
              id: _text(row['id']),
              name: _text(row['name']),
              description: _nullableText(row['description']),
              isSystem: _bool(row['is_system']),
              isActive: _bool(row['is_active'], fallback: true),
            ),
          )
          .toList();
    });
  }

  @override
  Future<AppResult<AccessRole>> saveRole(AccessRole role) async {
    return _guard('role_save_failed', 'No se pudo guardar rol.', () async {
      await _rpc('app_upsert_role', {
        'p_restaurant_id': _restaurantId,
        'p_payload': {
          'id': role.id,
          'code': role.id,
          'name': role.name,
          'description': role.description,
          'is_system': role.isSystem,
          'is_active': role.isActive,
        },
      });
      return role;
    });
  }

  @override
  Future<AppResult<List<AccessPermission>>> getPermissions() async {
    return _guard(
      'permissions_read_failed',
      'No se pudieron leer permisos.',
      () async {
        final rows = await _getRows('permissions', {
          'select': 'code,name,description',
          'order': 'code.asc',
        });
        return rows
            .map(
              (row) => AccessPermission(
                code: _text(row['code']),
                name: _text(row['name']),
                description: _nullableText(row['description']),
              ),
            )
            .toList();
      },
    );
  }

  @override
  Future<AppResult<AccessPermission>> savePermission(
    AccessPermission permission,
  ) async {
    return _guard(
      'permission_save_failed',
      'No se pudo guardar permiso.',
      () async {
        await _rpc('app_upsert_permission', {
          'p_restaurant_id': _restaurantId,
          'p_payload': {
            'code': permission.code,
            'name': permission.name,
            'description': permission.description,
          },
        });
        return permission;
      },
    );
  }

  @override
  Future<AppResult<void>> setRolePermissions({
    required String roleId,
    required List<String> permissionCodes,
  }) async {
    return _guard(
      'role_permissions_save_failed',
      'No se pudieron guardar permisos del rol.',
      () async {
        await _rpc('app_replace_role_permissions', {
          'p_restaurant_id': _restaurantId,
          'p_role_id': roleId,
          'p_permission_codes': permissionCodes.toSet().toList()..sort(),
        });
      },
    );
  }

  @override
  Future<AppResult<List<String>>> getPermissionCodesForRole(
    String roleId,
  ) async {
    return _guard(
      'role_permissions_read_failed',
      'No se pudieron leer permisos del rol.',
      () async {
        final rows = await _getRows('role_permissions', {
          'role_id': 'eq.$roleId',
          'select': 'permissions(code)',
        });
        return [
          for (final row in rows)
            _text((row['permissions'] as Map<String, Object?>?)?['code']),
        ].where((code) => code.isNotEmpty).toList();
      },
    );
  }

  @override
  Future<AppResult<List<AppUserProfile>>> getUsers() async {
    return _guard(
      'users_read_failed',
      'No se pudieron leer usuarios.',
      () async {
        final rows = await _getRows('profiles', {
          'restaurant_id': 'eq.$_restaurantId',
          'select':
              'id,display_name,email,role_id,is_active,is_pos_user,pin_salt,'
              'pin_hash',
          'order': 'display_name.asc',
        });
        return rows
            .map(
              (row) => AppUserProfile(
                id: _text(row['id']),
                displayName: _text(row['display_name']),
                email: _text(row['email']),
                roleId: _text(row['role_id']),
                isActive: _bool(row['is_active'], fallback: true),
                isPosUser: _bool(row['is_pos_user']),
                pinSalt: _nullableText(row['pin_salt']),
                pinHash: _nullableText(row['pin_hash']),
              ),
            )
            .toList();
      },
    );
  }

  @override
  Future<AppResult<AppUserProfile>> saveUser(
    AppUserProfile user, {
    String? pin,
  }) async {
    return _guard('user_save_failed', 'No se pudo guardar usuario.', () async {
      final userToSave = _withUpdatedPin(user, pin);
      await _rpc('app_upsert_profile', {
        'p_restaurant_id': _restaurantId,
        'p_payload': {
          'id': userToSave.id,
          'display_name': userToSave.displayName,
          'email': userToSave.email,
          'role_id': userToSave.roleId,
          'is_active': userToSave.isActive,
          'is_pos_user': userToSave.isPosUser,
          'pin_salt': userToSave.pinSalt,
          'pin_hash': userToSave.pinHash,
        },
      });
      return userToSave;
    });
  }

  @override
  Future<AppResult<AuditLogEntry>> saveEntry(AuditLogEntry entry) async {
    return _guard(
      'audit_save_failed',
      'No se pudo guardar auditoria.',
      () async {
        await _upsert('audit_logs', {
          'id': entry.id,
          'restaurant_id': _restaurantId,
          'actor_user_id': _uuidOrNull(entry.actorUserId) ?? _remoteUserId,
          'action': entry.action,
          'entity_name': entry.entityName,
          'entity_id': _uuidOrNull(entry.entityId),
          'details': entry.details,
          'created_at': entry.occurredAt.toIso8601String(),
        });
        return entry;
      },
    );
  }

  @override
  Future<AppResult<List<AuditLogEntry>>> getEntriesByDate(DateTime date) async {
    return _guard('audit_read_failed', 'No se pudo leer auditoria.', () async {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      final rows = await _getRows('audit_logs', {
        'restaurant_id': 'eq.$_restaurantId',
        'and':
            '(created_at.gte.${start.toIso8601String()},'
            'created_at.lt.${end.toIso8601String()})',
        'select':
            'id,actor_user_id,action,entity_name,entity_id,details,created_at',
        'order': 'created_at.desc',
      });
      return rows
          .map(
            (row) => AuditLogEntry(
              id: _text(row['id']),
              actorUserId: _nullableText(row['actor_user_id']),
              action: _text(row['action']),
              entityName: _text(row['entity_name']),
              entityId: _nullableText(row['entity_id']),
              details: _map(row['details']),
              occurredAt: _date(row['created_at']),
            ),
          )
          .toList();
    });
  }
}
