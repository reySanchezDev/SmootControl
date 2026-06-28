import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

void main() {
  group('PosCartLine', () {
    const product = Product(
      id: 'product-1',
      categoryId: 'food',
      name: 'Carne asada',
      priceInCents: 12000,
      costInCents: 6000,
      isActive: true,
    );

    test('uses selected options in its cart key', () {
      const tortilla = PosCartLine(
        product: product,
        quantity: 1,
        selectedOptions: [
          SelectedProductOption(
            groupName: 'Acompanamiento',
            optionName: 'Tortilla',
          ),
        ],
      );
      const tajadas = PosCartLine(
        product: product,
        quantity: 1,
        selectedOptions: [
          SelectedProductOption(
            groupName: 'Acompanamiento',
            optionName: 'Tajadas',
          ),
        ],
      );

      expect(tortilla.cartKey, isNot(tajadas.cartKey));
      expect(tortilla.selectedOptionsLabel, 'Acompanamiento: Tortilla');
    });
  });
}
