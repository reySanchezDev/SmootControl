import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/auth/domain/services/local_pin_hasher.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/repositories/i_sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';
import 'package:smoo_control/features/users/data/datasources/local_users_datasource.dart';
import 'package:smoo_control/features/users/data/models/app_user_profile_model.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';
import 'package:smoo_control/features/users/domain/repositories/i_users_repository.dart';

/// Users repository backed by the local offline database.
final class UsersRepository implements IUsersRepository {
  /// Creates a users repository.
  const UsersRepository(
    this._localDataSource, {
    ISyncQueueRepository? syncQueueRepository,
    ISyncRemoteSender? remoteSender,
    LocalPinHasher pinHasher = const LocalPinHasher(),
  }) : _syncQueueRepository = syncQueueRepository,
       _remoteSender = remoteSender,
       _pinHasher = pinHasher;

  final LocalUsersDataSource _localDataSource;
  final ISyncQueueRepository? _syncQueueRepository;
  final ISyncRemoteSender? _remoteSender;
  final LocalPinHasher _pinHasher;

  @override
  Future<AppResult<List<AppUserProfile>>> getUsers() async {
    try {
      final users = await _localDataSource.getUsers();
      return AppSuccess(users.map((user) => user.toEntity()).toList());
    } on Object catch (error) {
      return _failure(
        'users_read_failed',
        'No se pudieron leer usuarios.',
        error,
      );
    }
  }

  @override
  Future<AppResult<AppUserProfile>> saveUser(
    AppUserProfile user, {
    String? pin,
  }) async {
    try {
      final userToSave = _withUpdatedPin(user, pin);
      final model = AppUserProfileModel.fromEntity(userToSave);
      await _pushUserRemote(userToSave);
      final saved = await _localDataSource.saveUser(model);
      final entity = saved.toEntity();
      if (_remoteSender == null) {
        await _enqueueUser(entity);
      }

      return AppSuccess(entity);
    } on Object catch (error) {
      return _failure('user_save_failed', 'No se pudo guardar usuario.', error);
    }
  }

  AppUserProfile _withUpdatedPin(AppUserProfile user, String? pin) {
    final normalizedPin = pin?.trim();
    if (normalizedPin == null || normalizedPin.isEmpty) {
      return user;
    }

    final salt = _pinHasher.generateSalt();
    final hash = _pinHasher.hashPin(pin: normalizedPin, salt: salt);
    return user.copyWith(pinSalt: salt, pinHash: hash);
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

  Future<void> _enqueueUser(AppUserProfile user) async {
    await _syncQueueRepository?.enqueue(
      entityType: 'profiles',
      entityId: user.id,
      operation: SyncOperation.create,
      payload: {
        'id': user.id,
        'displayName': user.displayName,
        'email': user.email,
        'roleId': user.roleId,
        'isPosUser': user.isPosUser,
        'isActive': user.isActive,
        'pinSalt': user.pinSalt,
        'pinHash': user.pinHash,
        'hasLocalPin': user.hasLocalPin,
      },
    );
  }

  Future<void> _pushUserRemote(AppUserProfile user) async {
    final remoteSender = _remoteSender;
    if (remoteSender == null) return;

    final now = DateTime.now();
    await remoteSender.push(
      SyncQueueItem(
        id: 'admin-direct-profiles-${user.id}',
        entityType: 'profiles',
        entityId: user.id,
        operation: SyncOperation.create,
        payload: {
          'id': user.id,
          'displayName': user.displayName,
          'email': user.email,
          'roleId': user.roleId,
          'isPosUser': user.isPosUser,
          'isActive': user.isActive,
          'pinSalt': user.pinSalt,
          'pinHash': user.pinHash,
          'hasLocalPin': user.hasLocalPin,
        },
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
