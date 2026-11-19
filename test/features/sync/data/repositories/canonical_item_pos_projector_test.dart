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

    await CanonicalItemPosProjector(database).project(
      'restaurant-1',
      modifierIdsByItem: const {
        'item-1': ['group-1', 'group-2'],
      },
    );

    final products = await database.select(database.localProducts).get();
    expect(products, hasLength(1));
    expect(products.single.id, 'item-1');
    expect(products.single.priceInCents, 12500);
    expect(products.single.sourceKind, 'canonical_item');
    expect(products.single.categoryId, '__canonical_uncategorized__');
    expect(products.single.modifierGroupIdsJson, '["group-1","group-2"]');
  });

  test(
    'projects canonical packaging into the local packaging read model',
    () async {
      await database
          .into(database.localCanonicalItems)
          .insert(
            LocalCanonicalItemsCompanion.insert(
              id: 'packaging-1',
              restaurantId: 'restaurant-1',
              code: 'ART-3',
              name: 'Empaque canónico',
              itemType: 'inventory',
              baseUnitId: 'unit-1',
              canSell: false,
              visibleInPos: false,
              isActive: true,
              itemClass: const Value('packaging'),
              tracksInventory: const Value(true),
              quantityOnHand: const Value(7),
            ),
          );

      await CanonicalItemPosProjector(database).project('restaurant-1');

      final packaging = await database
          .select(database.localPackagingItems)
          .get();
      final stock = await database.select(database.localPackagingStock).get();
      expect(packaging.single.id, 'packaging-1');
      expect(packaging.single.tracksStock, isTrue);
      expect(stock.single.quantityOnHand, 7);
      expect(await database.select(database.localProducts).get(), isEmpty);
    },
  );

  test(
    'clears stale stock when canonical packaging stops tracking it',
    () async {
      await database
          .into(database.localCanonicalItems)
          .insert(
            LocalCanonicalItemsCompanion.insert(
              id: 'packaging-no-stock',
              restaurantId: 'restaurant-1',
              code: 'ART-4',
              name: 'Packaging no stock',
              itemType: 'non_inventory',
              itemClass: const Value('packaging'),
              baseUnitId: 'unit-1',
              canSell: false,
              visibleInPos: false,
              isActive: true,
              tracksInventory: const Value(false),
            ),
          );
      await database
          .into(database.localPackagingStock)
          .insert(
            LocalPackagingStockCompanion.insert(
              packagingItemId: 'packaging-no-stock',
              quantityOnHand: const Value(5),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          );

      await CanonicalItemPosProjector(database).project('restaurant-1');

      final packaging = await database
          .select(database.localPackagingItems)
          .get();
      final stock = await database.select(database.localPackagingStock).get();
      expect(packaging.single.id, 'packaging-no-stock');
      expect(packaging.single.tracksStock, isFalse);
      expect(stock.single.quantityOnHand, 0);
    },
  );
}
