import 'dart:convert';

import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

/// Encodes and decodes product option groups for local persistence.
final class ProductOptionGroupCodec {
  const ProductOptionGroupCodec._();

  /// Converts option groups to JSON.
  static String encode(List<ProductOptionGroup> groups) {
    final data = [
      for (final group in groups.where((group) => group.isUsable))
        {
          'name': group.name.trim(),
          'isRequired': group.isRequired,
          'options': [
            for (final option in group.options)
              if (option.trim().isNotEmpty) option.trim(),
          ],
        },
    ];

    return jsonEncode(data);
  }

  /// Converts JSON to option groups.
  static List<ProductOptionGroup> decode(String source) {
    if (source.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];

      return [
        for (final item in decoded)
          if (item is Map<String, Object?>)
            ProductOptionGroup(
              name: (item['name'] as String? ?? '').trim(),
              isRequired: item['isRequired'] as bool? ?? true,
              options: [
                if (item['options'] is List)
                  for (final option in item['options']! as List)
                    if (option is String && option.trim().isNotEmpty)
                      option.trim(),
              ],
            ),
      ].where((group) => group.isUsable).toList();
    } on FormatException {
      return const [];
    }
  }
}
