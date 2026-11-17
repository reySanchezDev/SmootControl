import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sync/data/repositories/canonical_item_pos_projector.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('projects sellable canonical items into the POS read model', () async {
    await database
        .into(database.localCanonicalItems)
        .insert(
          LocalCanonicalItemsCompanion.insert(
            id: 'item-1',
            restaurantId: 'restaurant-1',
            code: 'ART-1',
            name: 'Pollo canónico',
            itemType: 'non_inventory',
            baseUnitId: 'unit-1',
            canSell: true,
            visibleInPos: true,
            isActive: true,
        commercialCode: const Value('45'),
        priceInCents: const Value(12500),
        costInCents: const Value(7000),
          ),
        );

    await database
        .into(database.localCanonicalItems)
        .insert(
          LocalCanonicalItemsCompanion.insert(
            id: 'item-2',
            restaurantId: 'restaurant-1',
            code: 'ART-2',
            name: 'No vendible',
            itemType: 'inventory',
            baseUnitId: 'unit-1',
            canSell: false,
            visibleInPos: false,
            isActive: true,
          ),
        );

    await CanonicalItemPosProjector(database).project('restaurant-1');

    final products = await database.select(database.localProducts).get();
    expect(products, hasLength(1));
    expect(products.single.id, 'item-1');
    expect(products.single.priceInCents, 12500);
    expect(products.single.sourceKind, 'canonical_item');
    expect(products.single.categoryId, '__canonical_uncategorized__');
  });
}
