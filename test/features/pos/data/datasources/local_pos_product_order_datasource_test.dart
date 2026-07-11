import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/pos/data/datasources/local_pos_product_order_datasource.dart';

void main() {
  group('LocalPosProductOrderDataSource', () {
    late AppDatabase database;
    late LocalPosProductOrderDataSource dataSource;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      dataSource = LocalPosProductOrderDataSource(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('stores product order locally by category', () async {
      final saved = await dataSource.saveCategoryOrder(
        categoryId: 'extras',
        productIds: const ['maduro', 'arroz', 'frijoles'],
      );

      expect(saved, {'maduro': 0, 'arroz': 1, 'frijoles': 2});

      final loaded = await dataSource.getProductOrderById();
      expect(loaded, saved);
    });

    test('reset clears only the selected category order', () async {
      await dataSource.saveCategoryOrder(
        categoryId: 'extras',
        productIds: const ['maduro', 'arroz'],
      );
      await dataSource.saveCategoryOrder(
        categoryId: 'bebidas',
        productIds: const ['coca'],
      );

      final reset = await dataSource.resetCategoryOrder('extras');

      expect(reset, {'coca': 0});
    });

    test('stores table order locally', () async {
      final saved = await dataSource.saveTableOrder(
        tableIds: const ['mesa-3', 'mesa-1', 'mesa-2'],
      );

      expect(saved, {'mesa-3': 0, 'mesa-1': 1, 'mesa-2': 2});

      final loaded = await dataSource.getTableOrderById();
      expect(loaded, saved);
    });
  });
}
