import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('stores and reads local product categories', () async {
      final now = DateTime(2026, 6, 23);

      await database
          .into(database.localProductCategories)
          .insert(
            LocalProductCategoriesCompanion.insert(
              id: 'category-1',
              name: 'Cafe Caliente',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final categories = await database
          .select(database.localProductCategories)
          .get();

      expect(categories, hasLength(1));
      expect(categories.single.name, 'Cafe Caliente');
      expect(categories.single.syncStatus, 'pending');
    });

    test('stores sync queue entries as pending by default', () async {
      final now = DateTime(2026, 6, 23);

      await database
          .into(database.localSyncQueue)
          .insert(
            LocalSyncQueueCompanion.insert(
              id: 'sync-1',
              entityType: 'sale',
              entityId: 'sale-1',
              operation: 'create',
              payloadJson: '{}',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final entries = await database.select(database.localSyncQueue).get();

      expect(entries.single.status, 'pending');
      expect(entries.single.retryCount, 0);
    });
  });
}
