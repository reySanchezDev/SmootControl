import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

/// Value emitted by the product option groups editor.
final class ProductOptionGroupsEditorValue {
  /// Creates an editor value.
  const ProductOptionGroupsEditorValue({
    required this.groups,
    required this.hasInvalidInput,
  });

  /// Creates a valid value from existing groups.
  const ProductOptionGroupsEditorValue.valid(this.groups)
    : hasInvalidInput = false;

  /// Configured option groups.
  final List<ProductOptionGroup> groups;

  /// Whether the current draft has partially configured rows.
  final bool hasInvalidInput;
}
