import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/recipes/domain/entities/canonical_recipe.dart';

void main() {
  test('ingredient references canonical UUID and measured quantity', () {
    const line = CanonicalRecipeLine(
      componentItemId: 'ingredient-uuid',
      unitId: 'kg-uuid',
      quantity: 0.125,
      wastePercent: 5,
    );
    expect(line.toPayload(2), {
      'component_item_id': 'ingredient-uuid',
      'unit_id': 'kg-uuid',
      'quantity': 0.125,
      'waste_percent': 5.0,
      'display_order': 2,
    });
  });

  test('recipe keeps identity and active version', () {
    const recipe = CanonicalRecipe(
      id: 'recipe-uuid',
      itemId: 'burger-uuid',
      version: 3,
      lines: [
        CanonicalRecipeLine(
          componentItemId: 'meat-uuid',
          unitId: 'kg-uuid',
          quantity: 0.15,
        ),
      ],
    );
    expect(recipe.version, 3);
    expect(recipe.lines.single.componentItemId, 'meat-uuid');
  });

  test('server recipe component parser retains the unit and waste', () {
    final line = CanonicalRecipeLine.fromRow({
      'component_item_id': 'bread-uuid',
      'unit_id': 'unit-uuid',
      'quantity': '2.00',
      'waste_percent': '0.5',
    });
    expect(line.quantity, 2);
    expect(line.wastePercent, 0.5);
    expect(line.toPayload(0)['component_item_id'], 'bread-uuid');
  });
}
