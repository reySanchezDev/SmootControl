import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sync/data/repositories/item_catalog_snapshot_applier.dart';
import 'item_catalog_snapshot_applier_test_fixtures.dart' as fixture;

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => database.close());

  test('rolls back projection and snapshot as one transaction', () async {
    final applier = ItemCatalogSnapshotApplier(database);
    await expectLater(
      applier.apply(
        fixture.snapshot(revision: 1),
        beforeCommit: () async {
          await database
              .into(database.localProducts)
              .insert(
                LocalProductsCompanion.insert(
                  id: 'projected-item',
                  categoryId: 'category',
                  name: 'Projected',
                  priceInCents: 100,
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
              );
          throw StateError('simulated_projection_failure');
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(await database.select(database.localCanonicalItems).get(), isEmpty);
    expect(
      await database.select(database.localCanonicalCatalogSnapshots).get(),
      isEmpty,
    );
    expect(await database.select(database.localProducts).get(), isEmpty);
  });
}
