import 'package:smoo_control/features/sync/domain/entities/item_catalog_snapshot_v2.dart';

const restaurantId = '11111111-1111-4111-8111-111111111111';
const otherRestaurantId = '22222222-2222-4222-8222-222222222222';
const itemId = '33333333-3333-4333-8333-333333333333';
const unitId = '44444444-4444-4444-8444-444444444444';
const classificationId = '55555555-5555-4555-8555-555555555555';
const ruleId = '66666666-6666-4666-8666-666666666666';
const baseSnapshotId = '77777777-7777-4777-8777-777777777777';

ItemCatalogSnapshotV2 otherTenantSnapshot({required int revision}) {
  final json = jsonSnapshot()
    ..['restaurant_id'] = otherRestaurantId
    ..['revision'] = revision
    ..['snapshot_id'] = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const otherItemId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const otherClassId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  const otherRuleId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  (json['items']! as List<Map<String, Object?>>).single
    ..['restaurant_id'] = otherRestaurantId
    ..['id'] = otherItemId;
  (json['item_units']! as List<Map<String, Object?>>).single
    ..['restaurant_id'] = otherRestaurantId
    ..['item_id'] = otherItemId;
  (json['item_classifications']! as List<Map<String, Object?>>).single
    ..['restaurant_id'] = otherRestaurantId
    ..['id'] = otherClassId;
  (json['item_classification_links']! as List<Map<String, Object?>>).single
    ..['restaurant_id'] = otherRestaurantId
    ..['item_id'] = otherItemId
    ..['classification_id'] = otherClassId;
  (json['consumption_rules']! as List<Map<String, Object?>>).single
    ..['restaurant_id'] = otherRestaurantId
    ..['id'] = otherRuleId
    ..['consumed_item_id'] = otherItemId;
  return ItemCatalogSnapshotV2.fromJson(
    json,
    expectedRestaurantId: otherRestaurantId,
  );
}

ItemCatalogSnapshotV2 snapshot({
  required int revision,
  String snapshotId = baseSnapshotId,
}) => ItemCatalogSnapshotV2.fromJson(
  jsonSnapshot()
    ..['revision'] = revision
    ..['snapshot_id'] = snapshotId,
  expectedRestaurantId: restaurantId,
);

Map<String, Object?> jsonSnapshot() => {
  'restaurant_id': restaurantId,
  'contract_version': 2,
  'snapshot_complete': true,
  'snapshot_id': baseSnapshotId,
  'revision': 1,
  'items': [
    {
      'restaurant_id': restaurantId,
      'id': itemId,
      'code': 'RAW-1',
      'commercial_code': 1,
      'name': 'Pulpa',
      'item_type': 'inventory',
      'item_class': 'raw_material',
      'tracks_inventory': true,
      'base_unit_id': unitId,
      'base_unit_cost': 1,
      'base_unit_price': 0,
      'can_sell': false,
      'can_purchase': true,
      'visible_in_pos': false,
      'uses_recipe': false,
      'send_to_kitchen': false,
      'is_active': true,
    },
  ],
  'item_units': [
    {
      'restaurant_id': restaurantId,
      'item_id': itemId,
      'unit_id': unitId,
      'quantity_in_base': '1',
    },
  ],
  'item_classifications': [
    {
      'restaurant_id': restaurantId,
      'id': classificationId,
      'code': 'RAW',
      'name': 'Materia prima',
      'is_active': true,
    },
  ],
  'item_classification_links': [
    {
      'restaurant_id': restaurantId,
      'item_id': itemId,
      'classification_id': classificationId,
    },
  ],
  'consumption_rules': [
    {
      'restaurant_id': restaurantId,
      'id': ruleId,
      'source_item_id': null,
      'consumed_item_id': itemId,
      'unit_id': unitId,
      'scope': 'per_order',
      'quantity': '1.5',
    },
  ],
};
