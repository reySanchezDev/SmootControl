import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sync/data/repositories/item_catalog_snapshot_applier.dart';
import 'package:smoo_control/features/sync/domain/entities/item_catalog_snapshot_v2.dart';

const _restaurantId = '11111111-1111-4111-8111-111111111111';
const _otherRestaurantId = '22222222-2222-4222-8222-222222222222';
const _itemId = '33333333-3333-4333-8333-333333333333';
const _unitId = '44444444-4444-4444-8444-444444444444';
const _classificationId = '55555555-5555-4555-8555-555555555555';
const _ruleId = '66666666-6666-4666-8666-666666666666';
const _snapshotId = '77777777-7777-4777-8777-777777777777';

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
      ).apply(_snapshot(revision: 1));

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
      await applier.apply(_snapshot(revision: 2));

      await expectLater(
        applier.apply(_snapshot(revision: 1)),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        applier.apply(
          _snapshot(
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
        _snapshotId,
      );
    },
  );

  test(
    'rejects partial and cross-restaurant snapshots before applying',
    () async {
      final partial = _jsonSnapshot()..['snapshot_complete'] = false;
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          partial,
          expectedRestaurantId: _restaurantId,
        ),
        throwsA(isA<FormatException>()),
      );

      final crossTenant = _jsonSnapshot()
        ..['restaurant_id'] = _otherRestaurantId;
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          crossTenant,
          expectedRestaurantId: _restaurantId,
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
    await applier.apply(_snapshot(revision: 1));
    await applier.apply(_otherTenantSnapshot(revision: 1));
    await applier.apply(
      _snapshot(
        revision: 2,
        snapshotId: '88888888-8888-4888-8888-888888888888',
      ),
    );

    final catalogs = await database
        .select(database.localCanonicalCatalogSnapshots)
        .get();
    expect(catalogs, hasLength(2));
    expect(
      catalogs.singleWhere(
        (row) => row.restaurantId == _otherRestaurantId,
      ).revision,
      1,
    );
    expect(await database.select(database.localCanonicalItems).get(),
        hasLength(2));
    expect(await database.select(database.localCanonicalItemUnits).get(),
        hasLength(2));
    expect(await database.select(database.localCanonicalClassifications).get(),
        hasLength(2));
    expect(
      await database.select(database.localCanonicalClassificationLinks).get(),
      hasLength(2),
    );
    expect(await database.select(database.localCanonicalConsumptionRules).get(),
        hasLength(2));
  });

  test('serializes concurrent revisions and preserves the newest', () async {
    final applier = ItemCatalogSnapshotApplier(database);
    final newer = _snapshot(
      revision: 3,
      snapshotId: '99999999-9999-4999-8999-999999999999',
    );
    final older = _snapshot(
      revision: 2,
      snapshotId: '88888888-8888-4888-8888-888888888888',
    );
    final outcomes = await Future.wait([
      applier.apply(newer),
      applier.apply(older).then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);
    expect(outcomes.first, isTrue);
    expect(outcomes.last, isA<FormatException>());
    expect(
      (await database.select(database.localCanonicalCatalogSnapshots).get())
          .single.revision,
      3,
    );
  });

  test('two terminal offline replay keeps pending sales', () async {
    final terminalA = AppDatabase(NativeDatabase.memory());
    final terminalB = AppDatabase(NativeDatabase.memory());
    try {
      final applierA = ItemCatalogSnapshotApplier(terminalA);
      final applierB = ItemCatalogSnapshotApplier(terminalB);
      final first = _snapshot(revision: 1);
      final second = _snapshot(
        revision: 2,
        snapshotId: '88888888-8888-4888-8888-888888888888',
      );

      await Future.wait([
        applierA.apply(first),
        applierB.apply(first),
      ]);
      await terminalB.into(terminalB.localSyncQueue).insert(
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

      // Terminal B remains offline while terminal A receives a new revision.
      expect(await applierA.apply(second), isTrue);
      expect(
        (await terminalB.select(
          terminalB.localCanonicalCatalogSnapshots,
        ).get()).single.revision,
        1,
      );
      expect(
        await terminalB.select(terminalB.localSyncQueue).get(),
        hasLength(1),
      );

      // After reconnect, terminal B must accept the same canonical version.
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
    await applier.apply(_snapshot(revision: 1));

    final failingApplier = ItemCatalogSnapshotApplier(
      database,
      beforeSnapshotMetadataWrite: () async {
        throw StateError('simulated_local_commit_failure');
      },
    );
    await expectLater(
      failingApplier.apply(
        _snapshot(
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

ItemCatalogSnapshotV2 _otherTenantSnapshot({required int revision}) {
  final json = _jsonSnapshot();
  json['restaurant_id'] = _otherRestaurantId;
  json['revision'] = revision;
  json['snapshot_id'] = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  final items = json['items']! as List<Map<String, Object?>>;
  final units = json['item_units']! as List<Map<String, Object?>>;
  final classes = json['item_classifications']! as List<Map<String, Object?>>;
  final links =
      json['item_classification_links']! as List<Map<String, Object?>>;
  final rules = json['consumption_rules']! as List<Map<String, Object?>>;
  const otherItemId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const otherClassId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  const otherRuleId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  items.single
    ..['restaurant_id'] = _otherRestaurantId
    ..['id'] = otherItemId;
  units.single
    ..['restaurant_id'] = _otherRestaurantId
    ..['item_id'] = otherItemId;
  classes.single
    ..['restaurant_id'] = _otherRestaurantId
    ..['id'] = otherClassId;
  links.single
    ..['restaurant_id'] = _otherRestaurantId
    ..['item_id'] = otherItemId
    ..['classification_id'] = otherClassId;
  rules.single
    ..['restaurant_id'] = _otherRestaurantId
    ..['id'] = otherRuleId
    ..['consumed_item_id'] = otherItemId;
  return ItemCatalogSnapshotV2.fromJson(
    json,
    expectedRestaurantId: _otherRestaurantId,
  );
}

ItemCatalogSnapshotV2 _snapshot({
  required int revision,
  String snapshotId = _snapshotId,
}) {
  return ItemCatalogSnapshotV2.fromJson(
    _jsonSnapshot()
      ..['revision'] = revision
      ..['snapshot_id'] = snapshotId,
    expectedRestaurantId: _restaurantId,
  );
}

Map<String, Object?> _jsonSnapshot() {
  return {
    'restaurant_id': _restaurantId,
    'contract_version': 2,
    'snapshot_complete': true,
    'snapshot_id': _snapshotId,
    'revision': 1,
    'items': [
      {
        'restaurant_id': _restaurantId,
        'id': _itemId,
        'code': 'RAW-1',
        'name': 'Pulpa',
        'item_type': 'inventory',
        'base_unit_id': _unitId,
        'can_sell': false,
        'visible_in_pos': false,
        'is_active': true,
      },
    ],
    'item_units': [
      {
        'restaurant_id': _restaurantId,
        'item_id': _itemId,
        'unit_id': _unitId,
        'quantity_in_base': '1',
      },
    ],
    'item_classifications': [
      {
        'restaurant_id': _restaurantId,
        'id': _classificationId,
        'code': 'RAW',
        'name': 'Materia prima',
        'is_active': true,
      },
    ],
    'item_classification_links': [
      {
        'restaurant_id': _restaurantId,
        'item_id': _itemId,
        'classification_id': _classificationId,
      },
    ],
    'consumption_rules': [
      {
        'restaurant_id': _restaurantId,
        'id': _ruleId,
        'source_item_id': null,
        'consumed_item_id': _itemId,
        'unit_id': _unitId,
        'scope': 'per_order',
        'quantity': '1.5',
      },
    ],
  };
}
