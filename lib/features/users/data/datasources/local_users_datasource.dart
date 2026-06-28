import 'package:drift/drift.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/users/data/models/app_user_profile_model.dart';

/// Local datasource for app users.
final class LocalUsersDataSource {
  /// Creates a local users datasource.
  const LocalUsersDataSource(this._database);

  final AppDatabase _database;

  /// Returns local user profiles.
  Future<List<AppUserProfileModel>> getUsers() async {
    final query = _database.select(_database.localUserProfiles)
      ..orderBy([(user) => OrderingTerm.asc(user.displayName)]);
    final rows = await query.get();

    return rows.map(AppUserProfileModel.fromLocal).toList();
  }

  /// Saves a local user profile.
  Future<AppUserProfileModel> saveUser(AppUserProfileModel user) async {
    final now = DateTime.now();
    await _database
        .into(_database.localUserProfiles)
        .insertOnConflictUpdate(
          LocalUserProfilesCompanion(
            id: Value(user.id),
            displayName: Value(user.displayName),
            email: Value(user.email),
            roleId: Value(user.roleId),
            pinSalt: Value(user.pinSalt),
            pinHash: Value(user.pinHash),
            isPosUser: Value(user.isPosUser),
            isActive: Value(user.isActive),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return user;
  }
}
