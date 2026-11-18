import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';

void main() {
  test('all three technical item types map to canonical SQL values', () {
    expect(CanonicalItemType.inventory.databaseValue, 'inventory');
    expect(CanonicalItemType.nonInventory.databaseValue, 'non_inventory');
    expect(CanonicalItemType.service.databaseValue, 'service');
    for (final type in CanonicalItemType.values) {
      expect(CanonicalItemType.parse(type.databaseValue), type);
    }
    expect(
      () => CanonicalItemType.parse('packaging'),
      throwsA(isA<FormatException>()),
    );
  });

  test('create request preserves independent packaging classification', () {
    const item = CanonicalItem(
      code: 'BAG-001',
      name: 'Bolsa para llevar',
      type: CanonicalItemType.inventory,
      baseUnitId: 'unit-id',
      cost: 2.5,
      canPurchase: true,
      classificationIds: ['packaging-id'],
    );
    final payload = item.toPayload();
    expect(payload.containsKey('id'), isFalse);
    expect(payload['item_type'], 'inventory');
    expect(payload['classification_ids'], ['packaging-id']);
    expect(payload['can_sell'], false);
    expect(payload['base_unit_cost'], 2.5);
  });

  test('parse keeps UUID and commercial settings from server', () {
    final item = CanonicalItem.fromRow({
      'id': 'item-id',
      'code': 'SERV-01',
      'name': 'Entrega',
      'item_type': 'service',
      'base_unit_id': 'unit-id',
      'base_unit_cost': '0',
      'base_unit_price': '50.50',
      'can_sell': true,
      'can_purchase': false,
      'visible_in_pos': true,
      'uses_recipe': false,
      'send_to_kitchen': false,
      'is_active': true,
    }, classificationIds: ['service-class']);
    expect(item.id, 'item-id');
    expect(item.type, CanonicalItemType.service);
    expect(item.price, 50.5);
    expect(item.toPayload()['id'], 'item-id');
    expect(item.classificationIds, ['service-class']);
  });

  test('invalid server item type is rejected instead of guessed', () {
    expect(
      () => CanonicalItem.fromRow({
        'id': 'item',
        'code': 'RAW',
        'name': 'Materia prima',
        'item_type': 'packaging',
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
