import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_catalog_tiles.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';

void main() {
  group('swapPosProductsForDrop', () {
    test('swaps only dragged and target products', () {
      final first = _product('1', 'Arroz');
      final second = _product('2', 'Frijoles');
      final third = _product('3', 'Maduro');
      final fourth = _product('4', 'Tajadas');

      final reordered = swapPosProductsForDrop(
        draggedProduct: third,
        products: [first, second, third, fourth],
        targetProduct: first,
      );

      expect(reordered, [third, second, first, fourth]);
    });

    test('keeps order when product is dropped over itself', () {
      final first = _product('1', 'Arroz');
      final second = _product('2', 'Frijoles');
      final products = [first, second];

      final reordered = swapPosProductsForDrop(
        draggedProduct: second,
        products: products,
        targetProduct: second,
      );

      expect(identical(reordered, products), isTrue);
    });
  });
}

Product _product(String id, String name) {
  return Product(
    id: id,
    categoryId: 'extras',
    name: name,
    priceInCents: 100,
    costInCents: 0,
    isActive: true,
  );
}
