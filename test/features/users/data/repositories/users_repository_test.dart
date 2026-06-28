import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/sync/data/datasources/local_sync_queue_datasource.dart';
import 'package:smoo_control/features/sync/data/repositories/sync_queue_repository.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/users/data/datasources/local_users_datasource.dart';
import 'package:smoo_control/features/users/data/repositories/users_repository.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';

void main() {
  group('UsersRepository', () {
    late AppDatabase database;
    late UsersRepository repository;
    late SyncQueueRepository syncQueueRepository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      syncQueueRepository = SyncQueueRepository(
        LocalSyncQueueDataSource(database),
      );
      repository = UsersRepository(
        LocalUsersDataSource(database),
        syncQueueRepository: syncQueueRepository,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('saves and returns local users', () async {
      const user = AppUserProfile(
        id: 'user-1',
        displayName: 'Rey Sanchez',
        email: 'rey@example.com',
        roleId: 'role-admin',
        isPosUser: false,
        isActive: true,
      );

      final saveResult = await repository.saveUser(user);
      final readResult = await repository.getUsers();
      final syncResult = await syncQueueRepository.getPendingItems();

      expect(saveResult, isA<AppSuccess<AppUserProfile>>());
      expect((readResult as AppSuccess<List<AppUserProfile>>).value, [user]);
      final syncItem =
          (syncResult as AppSuccess<List<SyncQueueItem>>).value.single;
      expect(syncItem.entityType, 'profiles');
      expect(syncItem.entityId, user.id);
      expect(syncItem.payload['roleId'], user.roleId);
    });
  });
}
