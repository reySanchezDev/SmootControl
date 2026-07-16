part of 'supabase_catalog_pull_service.dart';

extension on SupabaseCatalogPullService {
  Future<void> _applyPermissions(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    for (final row in rows) {
      final code = _optionalText(row['code']);
      if (code == null) continue;
      await _database
          .into(_database.localPermissions)
          .insert(
            LocalPermissionsCompanion(
              code: Value(code),
              name: Value(_text(row['name'], defaultValue: code)),
              description: Value(_optionalText(row['description'])),
              remoteId: Value(_optionalText(row['id'])),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _applyRoles(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'roles');
      await _database
          .into(_database.localRoles)
          .insert(
            LocalRolesCompanion(
              id: Value(id),
              name: Value(_text(row['name'], defaultValue: 'Rol')),
              description: Value(_optionalText(row['description'])),
              isSystem: Value(_bool(row['is_system'])),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _applyRolePermissions(
    List<Map<String, Object?>> rows,
    List<Map<String, Object?>> permissions,
    List<Map<String, Object?>> roles,
  ) async {
    final permissionCodeById = <String, String>{};
    for (final permission in permissions) {
      final id = _optionalText(permission['id']);
      final code = _optionalText(permission['code']);
      if (id != null && code != null) permissionCodeById[id] = code;
    }

    final remoteRoleIds = roles
        .map((role) => _optionalText(role['id']))
        .whereType<String>()
        .toSet();
    if (remoteRoleIds.isEmpty) return;

    final now = DateTime.now();
    await _database.batch((batch) {
      for (final roleId in remoteRoleIds) {
        batch.deleteWhere(
          _database.localRolePermissions,
          (assignment) => assignment.roleId.equals(roleId),
        );
      }
      for (final row in rows) {
        final roleId = _optionalText(row['role_id']);
        final permissionId = _optionalText(row['permission_id']);
        final permissionCode = permissionCodeById[permissionId];
        if (roleId == null ||
            permissionCode == null ||
            !remoteRoleIds.contains(roleId)) {
          continue;
        }
        batch.insert(
          _database.localRolePermissions,
          LocalRolePermissionsCompanion(
            id: Value('$roleId:$permissionCode'),
            roleId: Value(roleId),
            permissionCode: Value(permissionCode),
            remoteId: Value('$roleId:$permissionCode'),
            syncStatus: const Value('synced'),
            syncError: const Value(null),
            createdAt: Value(now),
            updatedAt: Value(now),
            syncedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _applyUsers(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'profiles');
      final existing = await (_database.select(
        _database.localUserProfiles,
      )..where((user) => user.id.equals(id))).getSingleOrNull();
      final roleId = _optionalText(row['role_id']) ?? existing?.roleId;
      if (roleId == null) continue;

      await _database
          .into(_database.localUserProfiles)
          .insert(
            LocalUserProfilesCompanion(
              id: Value(id),
              displayName: Value(
                _text(row['display_name'], defaultValue: 'Usuario'),
              ),
              email: Value(_text(row['email'], defaultValue: '')),
              roleId: Value(roleId),
              pinSalt: Value(
                _optionalText(row['pin_salt']) ?? existing?.pinSalt,
              ),
              pinHash: Value(
                _optionalText(row['pin_hash']) ?? existing?.pinHash,
              ),
              isPosUser: Value(
                _bool(
                  row['is_pos_user'],
                  defaultValue: existing?.isPosUser ?? false,
                ),
              ),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  Future<void> _applyEmployees(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final remoteIds = <String>{};
    for (final row in rows) {
      final id = _requiredText(row['id'], table: 'employees');
      remoteIds.add(id);
      await _database
          .into(_database.localEmployees)
          .insert(
            LocalEmployeesCompanion(
              id: Value(id),
              code: Value(_optionalText(row['code'])),
              fullName: Value(
                _text(row['full_name'], defaultValue: 'Empleado'),
              ),
              positionName: Value(_optionalText(row['position_name'])),
              baseSalaryInCents: Value(_moneyCents(row['base_salary'])),
              isActive: Value(_bool(row['is_active'], defaultValue: true)),
              remoteId: Value(id),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    await (_database.update(_database.localEmployees)..where((employee) {
          return remoteIds.isEmpty
              ? const Constant(false)
              : employee.id.isNotIn(remoteIds);
        }))
        .write(
          LocalEmployeesCompanion(
            isActive: const Value(false),
            updatedAt: Value(now),
            syncedAt: Value(now),
          ),
        );
  }

  Future<void> _applyBusinessRules(List<Map<String, Object?>> rows) async {
    final now = DateTime.now();
    final effectiveRows = [
      ...rows,
      if (!_hasRule(rows, 'salary_advance_pos_affects_cash'))
        {
          'key': 'salary_advance_pos_affects_cash',
          'bool_value': false,
          'text_value': null,
        },
      if (!_hasRule(rows, 'allow_raw_material_negative_stock_from_recipes'))
        {
          'key': 'allow_raw_material_negative_stock_from_recipes',
          'bool_value': true,
          'text_value': null,
        },
    ];
    for (final row in effectiveRows) {
      final key = _optionalText(row['key']);
      if (key == null) continue;
      await _database
          .into(_database.localBusinessRules)
          .insert(
            LocalBusinessRulesCompanion(
              key: Value(key),
              boolValue: Value(row['bool_value'] as bool?),
              textValue: Value(_optionalText(row['text_value'])),
              remoteId: Value(key),
              syncStatus: const Value('synced'),
              syncError: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
  }

  bool _hasRule(List<Map<String, Object?>> rows, String key) {
    return rows.any((row) => _optionalText(row['key']) == key);
  }
}
