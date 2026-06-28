import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';

/// Contract for local user profile management.
abstract interface class IUsersRepository {
  /// Returns local users.
  Future<AppResult<List<AppUserProfile>>> getUsers();

  /// Saves one local user profile.
  Future<AppResult<AppUserProfile>> saveUser(
    AppUserProfile user, {
    String? pin,
  });
}
