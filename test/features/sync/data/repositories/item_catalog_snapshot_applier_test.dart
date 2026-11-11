import 'package:drift/drift.dart';
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
