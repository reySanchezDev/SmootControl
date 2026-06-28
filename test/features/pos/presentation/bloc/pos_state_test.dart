import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

void main() {
  group('PosReady', () {
    test('resolves reusable modifier groups for POS product options', () {
      const food = Product(
        id: 'food-1',
        categoryId: 'category-1',
        name: 'Carne asada',
        priceInCents: 18000,
        costInCents: 9000,
        isActive: true,
        modifierGroupIds: ['modifier-sides'],
      );
      const state = PosReady(
        products: [food],
        paymentMethods: [],
        modifierCatalog: ModifierCatalog(
          groups: [
            ModifierGroup(id: 'modifier-sides', name: 'Guarnicion'),
          ],
          options: [
            ModifierOption(
              id: 'option-1',
              groupId: 'modifier-sides',
              name: 'Tajadas',
            ),
            ModifierOption(
              id: 'option-2',
              groupId: 'modifier-sides',
              name: 'Maduro frito',
              isAvailableInPos: false,
            ),
          ],
        ),
      );

      final groups = state.optionGroupsFor(food);

      expect(groups, hasLength(1));
      expect(groups.single.name, 'Guarnicion');
      expect(groups.single.options, ['Tajadas']);
    });

    test('does not duplicate legacy groups when reusable modifiers exist', () {
      const food = Product(
        id: 'food-1',
        categoryId: 'category-1',
        name: 'Res',
        priceInCents: 20000,
        costInCents: 10000,
        isActive: true,
        optionGroups: [
          ProductOptionGroup(
            name: 'Bastimento',
            options: ['Tortilla'],
          ),
          ProductOptionGroup(
            name: 'Guarnicion',
            options: ['Guiso de papas'],
          ),
        ],
        modifierGroupIds: ['modifier-bastimento', 'modifier-guarnicion'],
      );
      const state = PosReady(
        products: [food],
        paymentMethods: [],
        modifierCatalog: ModifierCatalog(
          groups: [
            ModifierGroup(id: 'modifier-bastimento', name: 'Bastimentos'),
            ModifierGroup(id: 'modifier-guarnicion', name: 'Guarnicion'),
          ],
          options: [
            ModifierOption(
              id: 'option-1',
              groupId: 'modifier-bastimento',
              name: 'Maduro frito',
            ),
            ModifierOption(
              id: 'option-2',
              groupId: 'modifier-guarnicion',
              name: 'Guiso de papas',
            ),
          ],
        ),
      );

      final groups = state.optionGroupsFor(food);

      expect(groups, hasLength(2));
      expect(groups.map((group) => group.name), [
        'Bastimentos',
        'Guarnicion',
      ]);
    });
  });
}
