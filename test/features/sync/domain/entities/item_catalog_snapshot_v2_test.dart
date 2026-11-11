import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/sync/domain/entities/item_catalog_snapshot_v2.dart';

const _restaurant = '00000000-0000-0000-0000-000000000001';
const _otherRestaurant = '00000000-0000-0000-0000-000000000002';
const _snapshotId = '10000000-0000-0000-0000-000000000001';
const _productId = '20000000-0000-0000-0000-000000000001';
const _packagingId = '20000000-0000-0000-0000-000000000002';
const _unitId = '30000000-0000-0000-0000-000000000001';
const _ruleId = '40000000-0000-0000-0000-000000000001';
const _classId = '50000000-0000-0000-0000-000000000001';

Map<String, Object?> _catalog({
  String tenant = _restaurant,
  bool complete = true,
  int revision = 7,
}) {
  return <String, Object?>{
    'contract_version': 2,
    'restaurant_id': tenant,
    'snapshot_id': _snapshotId,
    'snapshot_complete': complete,
    'revision': revision,
    'items': <Map<String, Object?>>[
      <String, Object?>{
        'restaurant_id': _restaurant,
        'id': _productId,
        'code': 'HAMB-01',
        'name': 'Hamburguesa',
        'item_type': 'non_inventory',
        'base_unit_id': _unitId,
        'can_sell': true,
        'visible_in_pos': true,
        'is_active': true,
      },
      <String, Object?>{
        'restaurant_id': _restaurant,
        'id': _packagingId,
        'code': 'BAG-01',
        'name': 'Bolsa',
        'item_type': 'inventory',
        'base_unit_id': _unitId,
        'can_sell': false,
        'visible_in_pos': false,
        'is_active': true,
      },
    ],
    'item_units': <Map<String, Object?>>[
      <String, Object?>{
        'restaurant_id': _restaurant,
        'item_id': _productId,
        'unit_id': _unitId,
        'quantity_in_base': '1.00000000',
      },
      <String, Object?>{
        'restaurant_id': _restaurant,
        'item_id': _packagingId,
        'unit_id': _unitId,
        'quantity_in_base': '1',
      },
    ],
    'item_classifications': <Map<String, Object?>>[
      <String, Object?>{
        'restaurant_id': _restaurant,
        'id': _classId,
        'code': 'PACKAGING',
        'name': 'Empaque',
        'is_active': true,
      },
    ],
    'item_classification_links': <Map<String, Object?>>[
      <String, Object?>{
        'restaurant_id': _restaurant,
        'item_id': _packagingId,
        'classification_id': _classId,
      },
    ],
    'consumption_rules': <Map<String, Object?>>[
      <String, Object?>{
        'restaurant_id': _restaurant,
        'id': _ruleId,
        'source_item_id': _productId,
        'consumed_item_id': _packagingId,
        'unit_id': _unitId,
        'scope': 'per_sale_line',
        'quantity': '1',
      },
    ],
  };
}

void main() {
  group('ItemCatalogSnapshotV2', () {
    test('accepts one canonical catalog with sellable and packaging items', () {
      final snapshot = ItemCatalogSnapshotV2.fromJson(
        _catalog(),
        expectedRestaurantId: _restaurant,
      );

      expect(snapshot.items, hasLength(2));
      expect(snapshot.items.first.type, ItemCatalogTypeV2.nonInventory);
      expect(snapshot.items.last.type, ItemCatalogTypeV2.inventory);
      expect(snapshot.consumptionRules, hasLength(1));
      expect(snapshot.units, hasLength(2));
      expect(snapshot.classifications, hasLength(1));
      expect(snapshot.classificationLinks, hasLength(1));
      expect(snapshot.items.last.canSell, isFalse);
      expect(snapshot.snapshotId, _snapshotId);
    });

    test('rejects partial snapshots before local inactivation', () {
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          _catalog(complete: false),
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects snapshots for another restaurant', () {
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          _catalog(tenant: _otherRestaurant),
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects rows carrying another restaurant id', () {
      final catalog = _catalog();
      final items = catalog['items']! as List<Map<String, Object?>>;
      items[1]['restaurant_id'] = _otherRestaurant;

      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects codes that differ only by case', () {
      final catalog = _catalog();
      final items = catalog['items']! as List<Map<String, Object?>>;
      items[1]['code'] = 'hamb-01';

      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects a missing unit for the canonical base unit', () {
      final catalog = _catalog();
      (catalog['item_units']! as List<Map<String, Object?>>).removeAt(1);

      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects base conversions other than exactly one', () {
      final catalog = _catalog();
      final units = catalog['item_units']! as List<Map<String, Object?>>;
      units.first['quantity_in_base'] = '12';

      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects consumed items that have no matching unit', () {
      final catalog = _catalog();
      final rules =
          catalog['consumption_rules']! as List<Map<String, Object?>>;
      rules.first['unit_id'] = '30000000-0000-0000-0000-000000000099';

      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects decimal quantities that would lose precision', () {
      final catalog = _catalog();
      final rules =
          catalog['consumption_rules']! as List<Map<String, Object?>>;
      rules.first['quantity'] = '0.0000001';

      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects service articles as physical consumed items', () {
      final catalog = _catalog();
      final items = catalog['items']! as List<Map<String, Object?>>;
      items.last['item_type'] = 'service';

      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects an order rule without a source for per-line scope', () {
      final catalog = _catalog();
      final rules =
          catalog['consumption_rules']! as List<Map<String, Object?>>;
      rules.first['source_item_id'] = null;

      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects missing classification collections', () {
      final catalog = _catalog()..remove('item_classifications');
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects classification links outside the local tenant', () {
      final catalog = _catalog();
      final links =
          catalog['item_classification_links']!
              as List<Map<String, Object?>>;
      links.single['restaurant_id'] = _otherRestaurant;
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects links to inactive classifications', () {
      final catalog = _catalog();
      final classes =
          catalog['item_classifications']!
              as List<Map<String, Object?>>;
      classes.single['is_active'] = false;
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate classification codes regardless of case', () {
      final catalog = _catalog();
      final classes =
          catalog['item_classifications']!
              as List<Map<String, Object?>>;
      classes.add(<String, Object?>{
        'restaurant_id': _restaurant,
        'id': '50000000-0000-0000-0000-000000000002',
        'code': 'packaging',
        'name': 'Duplicado',
        'is_active': true,
      });
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate item-classification assignments', () {
      final catalog = _catalog();
      final links =
          catalog['item_classification_links']!
              as List<Map<String, Object?>>;
      links.add(Map<String, Object?>.from(links.single));
      expect(
        () => ItemCatalogSnapshotV2.fromJson(
          catalog,
          expectedRestaurantId: _restaurant,
        ),
        throwsFormatException,
      );
    });

    test('does not apply a stale revision or conflicting replay', () {
      final snapshot = ItemCatalogSnapshotV2.fromJson(
        _catalog(),
        expectedRestaurantId: _restaurant,
      );

      expect(
        snapshot.decideAgainst(storedRevision: 6, storedSnapshotId: null),
        ItemCatalogUpdateDecisionV2.apply,
      );
      expect(
        snapshot.decideAgainst(
          storedRevision: 7,
          storedSnapshotId: _snapshotId,
        ),
        ItemCatalogUpdateDecisionV2.noChange,
      );
      expect(
        () => snapshot.decideAgainst(
          storedRevision: 8,
          storedSnapshotId: _snapshotId,
        ),
        throwsFormatException,
      );
      expect(
        () => snapshot.decideAgainst(
          storedRevision: 7,
          storedSnapshotId: '10000000-0000-0000-0000-000000000099',
        ),
        throwsFormatException,
      );
    });

    test('does not expose mutable collections to consumers', () {
      final snapshot = ItemCatalogSnapshotV2.fromJson(
        _catalog(),
        expectedRestaurantId: _restaurant,
      );

      expect(snapshot.items.clear, throwsUnsupportedError);
      expect(snapshot.units.clear, throwsUnsupportedError);
      expect(snapshot.classifications.clear, throwsUnsupportedError);
      expect(snapshot.classificationLinks.clear, throwsUnsupportedError);
      expect(
        snapshot.consumptionRules.clear,
        throwsUnsupportedError,
      );
    });
  });
}
