import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/products/data/models/product_option_group_codec.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

void main() {
  group('ProductOptionGroupCodec', () {
    test('keeps legacy option groups required by default', () {
      const source = '[{"name":"Base","options":["Arroz","Gallo pinto"]}]';

      final groups = ProductOptionGroupCodec.decode(source);

      expect(groups, hasLength(1));
      expect(groups.single.name, 'Base');
      expect(groups.single.isRequired, isTrue);
    });

    test('encodes and decodes optional option groups', () {
      const groups = [
        ProductOptionGroup(
          name: 'Salsa extra',
          options: ['Chimichurri', 'Picante'],
          isRequired: false,
        ),
      ];

      final decoded = ProductOptionGroupCodec.decode(
        ProductOptionGroupCodec.encode(groups),
      );

      expect(decoded.single, groups.single);
      expect(decoded.single.isRequired, isFalse);
    });
  });
}
