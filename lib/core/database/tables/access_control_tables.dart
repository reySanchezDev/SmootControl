import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/tables/sync_columns.dart';

/// Local roles available in the business.
class LocalRoles extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Visible role name.
  TextColumn get name => text()();

  /// Optional role description.
  TextColumn get description => text().nullable()();

  /// Whether this is a protected system role.
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  /// Whether the role can be assigned.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local permission catalog.
class LocalPermissions extends Table with SyncColumns {
  /// Stable permission code.
  TextColumn get code => text()();

  /// Visible permission name.
  TextColumn get name => text()();

  /// Optional permission description.
  TextColumn get description => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {code};
}

/// Permissions assigned to roles.
class LocalRolePermissions extends Table with SyncColumns {
  /// Local identifier.
  TextColumn get id => text()();

  /// Role identifier.
  TextColumn get roleId => text()();

  /// Permission code.
  TextColumn get permissionCode => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local user profile mapped to a role.
class LocalUserProfiles extends Table with SyncColumns {
  /// Local or auth provider user identifier.
  TextColumn get id => text()();

  /// Visible user name.
  TextColumn get displayName => text()();

  /// User email.
  TextColumn get email => text()();

  /// Assigned role identifier.
  TextColumn get roleId => text()();

  /// Salt used to validate the local access PIN.
  TextColumn get pinSalt => text().nullable()();

  /// Hash used to validate the local access PIN.
  TextColumn get pinHash => text().nullable()();

  /// Whether the user should enter the POS operational flow directly.
  BoolColumn get isPosUser => boolean().withDefault(const Constant(false))();

  /// Whether the user can access the app.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
