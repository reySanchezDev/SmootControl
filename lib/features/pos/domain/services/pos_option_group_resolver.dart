import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

/// Resolves POS option groups from legacy groups or reusable modifiers.
final class PosOptionGroupResolver {
  /// Resolves groups requested by the POS for one product.
  static List<ProductOptionGroup> resolve({
    required Product product,
    required ModifierCatalog modifierCatalog,
  }) {
    if (product.modifierGroupIds.isEmpty) {
      return product.optionGroups.where((group) => group.isUsable).toList();
    }

    final groups = <ProductOptionGroup>[];
    final addedGroupNames = <String>{};
    for (final groupId in product.modifierGroupIds) {
      final group = modifierCatalog.groupById(groupId);
      if (group == null || !group.isActive) continue;
      final normalizedName = group.name.trim().toUpperCase();
      if (!addedGroupNames.add(normalizedName)) continue;
      final options = modifierCatalog
          .optionsFor(groupId)
          .where((option) => option.isActive && option.isAvailableInPos)
          .map((option) => option.name)
          .toList();
      if (options.isEmpty) continue;
      groups.add(
        ProductOptionGroup(
          name: group.name,
          options: options,
          isRequired: group.isRequired,
        ),
      );
    }
    return groups;
  }
}
