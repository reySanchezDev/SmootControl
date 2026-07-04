import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/modifiers/data/datasources/local_modifiers_datasource.dart';
import 'package:smoo_control/features/modifiers/data/models/modifier_group_model.dart';
import 'package:smoo_control/features/modifiers/data/models/modifier_option_model.dart';
import 'package:smoo_control/features/modifiers/data/repositories/modifiers_repository.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/features/sync/domain/entities/sync_queue_item.dart';
import 'package:smoo_control/features/sync/domain/services/i_sync_remote_sender.dart';

void main() {
  group('ModifiersRepository', () {
    late AppDatabase database;
    late ModifiersRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = ModifiersRepository(
        LocalModifiersDataSource(database),
        remoteSender: const _FailingRemoteSender(),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'saves POS availability locally without remote sync',
      () async {
        const group = ModifierGroup(
          id: 'modifier-group-sides',
          name: 'Bastimento',
        );
        const option = ModifierOption(
          id: 'modifier-option-maduro',
          groupId: 'modifier-group-sides',
          name: 'Maduro frito',
          displayOrder: 1,
        );

        await LocalModifiersDataSource(database).saveGroup(
          ModifierGroupModel.fromEntity(group),
        );
        await LocalModifiersDataSource(database).saveOption(
          ModifierOptionModel.fromEntity(option),
        );

        const unavailableOption = ModifierOption(
          id: 'modifier-option-maduro',
          groupId: 'modifier-group-sides',
          name: 'Maduro frito',
          displayOrder: 1,
          isAvailableInPos: false,
        );

        final result = await repository.saveOptionAvailability(
          unavailableOption,
        );

        expect(result, isA<AppSuccess<ModifierOption>>());
        final rows = await database.select(database.localModifierOptions).get();
        expect(rows.single.isAvailableInPos, isFalse);
        expect(await database.select(database.localSyncQueue).get(), isEmpty);
      },
    );
  });
}

final class _FailingRemoteSender implements ISyncRemoteSender {
  const _FailingRemoteSender();

  @override
  Future<void> push(SyncQueueItem item) {
    throw StateError('remote should not be called');
  }
}
