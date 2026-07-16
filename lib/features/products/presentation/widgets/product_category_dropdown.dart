import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Category selector used by the product form.
class ProductCategoryDropdown extends StatelessWidget {
  /// Creates a product category dropdown.
  const ProductCategoryDropdown({
    required this.categories,
    required this.onChanged,
    required this.selectedCategoryId,
    super.key,
  });

  /// Categories available for assignment.
  final List<ProductCategory> categories;

  /// Currently selected category id.
  final String? selectedCategoryId;

  /// Callback invoked when the selection changes.
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: l10n.parentCategoryField),
      initialValue: selectedCategoryId,
      isExpanded: true,
      items: [
        for (final category in _activeCategories)
          DropdownMenuItem(
            value: category.id,
            child: AppText(
              _categoryLabel(category),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }

  List<ProductCategory> get _activeCategories {
    final active = categories.where((category) {
      return category.isActive || category.id == selectedCategoryId;
    }).toList();
    return _orderedCategories(active);
  }

  String _categoryLabel(ProductCategory category) {
    final names = <String>[category.name];
    var parentId = category.parentId;
    final visited = <String>{category.id};

    while (parentId != null && visited.add(parentId)) {
      final parent = _categoryById(parentId);
      if (parent == null) break;
      names.insert(0, parent.name);
      parentId = parent.parentId;
    }

    return names.join(' / ');
  }

  List<ProductCategory> _orderedCategories(List<ProductCategory> source) {
    final ordered = <ProductCategory>[];

    void addChildren(String? parentId) {
      final children =
          source.where((category) => category.parentId == parentId).toList()
            ..sort(
              (first, second) => first.sortOrder.compareTo(second.sortOrder),
            );

      for (final child in children) {
        ordered.add(child);
        addChildren(child.id);
      }
    }

    addChildren(null);
    for (final category in source) {
      if (!ordered.any((item) => item.id == category.id)) {
        ordered.add(category);
      }
    }
    return ordered;
  }

  ProductCategory? _categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}
