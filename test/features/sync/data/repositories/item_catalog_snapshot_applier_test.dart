import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sync/data/repositories/item_catalog_snapshot_applier.dart';
import 'package:smoo_control/features/sync/domain/entities/item_catalog_snapshot_v2.dart';
import 'item_catalog_snapshot_applier_test_fixtures.dart' as fixture;

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'applies the complete V2 catalog and preserves the sync queue',
    () async {
      await database
          .into(database.localSyncQueue)
          .insert(
            LocalSyncQueueCompanion.insert(
              id: 'offline-sale',
              entityType: 'sale',
              entityId: 'sale-1',
              operation: 'create',
              payloadJson: '{}',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          );

      final applied = await ItemCatalogSnapshotApplier(
        database,
      ).apply(fixture.snapshot(revision: 1));

      expect(applied, isTrue);
      expect(
        await database.select(database.localCanonicalItems).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.localCanonicalItemUnits).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.localCanonicalClassifications).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.localCanonicalClassificationLinks).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.localCanonicalConsumptionRules).get(),
        hasLength(1),
      );
      expect(
        (await database.select(database.localCanonicalCatalogSnapshots).get())
            .single
            .revision,
        1,
      );
      expect(
        await database.select(database.localSyncQueue).get(),
        hasLength(1),
      );
    },
  );
  test(
    'rejects stale and conflicting snapshots without changing local state',
    () async {
      final applier = ItemCatalogSnapshotApplier(database);
      await applier.apply(fixture.snapshot(revision: 2));

      await expectLater(
        applier.apply(fixture.snapshot(revision: 1)),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        applier.apply(
          fixture.snapshot(
            revision: 2,
            snapshotId: '88888888-8888-4888-8888-888888888888',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        (await database.select(database.localCanonicalCatalogSnapshots).get())
            .single
            .snapshotId,
        fixture.baseSnapshotId,
      );
    },
  );

  test(
    'rejects partial and cross-restaurant snapshots before applying',
    () async {
      final partial = fixture.jsonSnapshot()..['snapshot_complete'] = false;
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          partial,
          expectedRestaurantId: fixture.restaurantId,
        ),
        throwsA(isA<FormatException>()),
      );

      final crossTenant = fixture.jsonSnapshot()
        ..['restaurant_id'] = fixture.otherRestaurantId;
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          crossTenant,
          expectedRestaurantId: fixture.restaurantId,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        await database.select(database.localCanonicalCatalogSnapshots).get(),
        isEmpty,
      );
    },
  );

  test('preserves canonical catalogs belonging to other restaurants', () async {
    final applier = ItemCatalogSnapshotApplier(database);
    await applier.apply(fixture.snapshot(revision: 1));
    await applier.apply(fixture.otherTenantSnapshot(revision: 1));
    await applier.apply(
      fixture.snapshot(
        revision: 2,
        snapshotId: '88888888-8888-4888-8888-888888888888',
      ),
    );

    final catalogs = await database
        .select(database.localCanonicalCatalogSnapshots)
        .get();
    expect(catalogs, hasLength(2));
    expect(
      catalogs
          .singleWhere(
            (row) => row.restaurantId == fixture.otherRestaurantId,
          )
          .revision,
      1,
    );
    expect(
      await database.select(database.localCanonicalItems).get(),
      hasLength(2),
    );
    expect(
      await database.select(database.localCanonicalItemUnits).get(),
      hasLength(2),
    );
    expect(
      await database.select(database.localCanonicalClassifications).get(),
      hasLength(2),
    );
    expect(
      await database.select(database.localCanonicalClassificationLinks).get(),
      hasLength(2),
    );
    expect(
      await database.select(database.localCanonicalConsumptionRules).get(),
      hasLength(2),
    );
  });
  test('serializes concurrent revisions and preserves the newest', () async {
    final applier = ItemCatalogSnapshotApplier(database);
    final newer = fixture.snapshot(
      revision: 3,
      snapshotId: '99999999-9999-4999-8999-999999999999',
    );
    final older = fixture.snapshot(
      revision: 2,
      snapshotId: '88888888-8888-4888-8888-888888888888',
    );
    final outcomes = await Future.wait([
      applier.apply(newer),
      applier
          .apply(older)
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);
    expect(outcomes.first, isTrue);
    expect(outcomes.last, isA<FormatException>());
    expect(
      (await database.select(database.localCanonicalCatalogSnapshots).get())
          .single
          .revision,
      3,
    );
  });

  test('two terminal offline replay keeps pending sales', () async {
    final terminalA = AppDatabase(NativeDatabase.memory());
    final terminalB = AppDatabase(NativeDatabase.memory());
    try {
      final applierA = ItemCatalogSnapshotApplier(terminalA);
      final applierB = ItemCatalogSnapshotApplier(terminalB);
      final first = fixture.snapshot(revision: 1);
      final second = fixture.snapshot(
        revision: 2,
        snapshotId: '88888888-8888-4888-8888-888888888888',
      );

      await Future.wait([
        applierA.apply(first),
        applierB.apply(first),
      ]);
      await terminalB
          .into(terminalB.localSyncQueue)
          .insert(
            LocalSyncQueueCompanion.insert(
              id: 'offline-sale-terminal-b',
              entityType: 'sale',
              entityId: 'terminal-b-sale-1',
              operation: 'create',
              payloadJson: '{}',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          );

      expect(await applierA.apply(second), isTrue);
      expect(
        (await terminalB
                .select(
                  terminalB.localCanonicalCatalogSnapshots,
                )
                .get())
            .single
            .revision,
        1,
      );
      expect(
        await terminalB.select(terminalB.localSyncQueue).get(),
        hasLength(1),
      );

      expect(await applierB.apply(second), isTrue);
      for (final terminal in [terminalA, terminalB]) {
        final metadata = await terminal
            .select(terminal.localCanonicalCatalogSnapshots)
            .get();
        expect(metadata.single.revision, 2);
        expect(metadata.single.snapshotId, second.snapshotId);
        expect(
          await terminal.select(terminal.localCanonicalItems).get(),
          hasLength(1),
        );
      }
      expect(
        (await terminalB.select(terminalB.localSyncQueue).get()).single.id,
        'offline-sale-terminal-b',
      );
      expect(await applierB.apply(second), isFalse);
    } finally {
      await terminalA.close();
      await terminalB.close();
    }
  });

  test('rolls back every canonical table when a commit step fails', () async {
    final applier = ItemCatalogSnapshotApplier(database);
    await applier.apply(fixture.snapshot(revision: 1));

    final failingApplier = ItemCatalogSnapshotApplier(
      database,
      beforeSnapshotMetadataWrite: () async {
        throw StateError('simulated_local_commit_failure');
      },
    );
    await expectLater(
      failingApplier.apply(
        fixture.snapshot(
          revision: 2,
          snapshotId: '88888888-8888-4888-8888-888888888888',
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      (await database.select(database.localCanonicalCatalogSnapshots).get())
          .single
          .revision,
      1,
    );
    expect(
      await database.select(database.localCanonicalItems).get(),
      hasLength(1),
    );
  });
}
