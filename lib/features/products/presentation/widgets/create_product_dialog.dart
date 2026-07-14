import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/presentation/widgets/modifier_group_selector.dart';
import 'package:smoo_control/features/products/presentation/widgets/product_flags_section.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Dialog used to create a product.
class CreateProductDialog extends StatefulWidget {
  /// Creates the product dialog.
  const CreateProductDialog({
    required this.categories,
    required this.modifierGroups,
    this.product,
    super.key,
  });

  /// Categories and subcategories available for product assignment.
  final List<ProductCategory> categories;

  /// Reusable modifier groups available for assignment.
  final List<ModifierGroup> modifierGroups;

  /// Product being edited.
  final Product? product;

  @override
  State<CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends State<CreateProductDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController(text: '0');
  bool _isActive = true;
  bool _isAvailableInPos = true;
  bool _isRawMaterial = false;
  bool _tracksInventory = false;
  String? _error;
  String? _selectedCategoryId;
  final _selectedModifierGroupIds = <String>{};

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) {
      return;
    }

    _nameController.text = product.name;
    _priceController.text = MoneyFormatter.format(product.priceInCents);
    _costController.text = MoneyFormatter.format(product.costInCents);
    _selectedCategoryId = product.categoryId;
    _isActive = product.isActive;
    _isAvailableInPos = product.isAvailableInPos;
    _isRawMaterial = product.isRawMaterial;
    _tracksInventory = product.tracksInventory;
    _selectedModifierGroupIds.addAll(product.modifierGroupIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: AppText(
        widget.product == null
            ? l10n.createProductTitle
            : l10n.editProductTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInput(label: l10n.nameField, controller: _nameController),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: l10n.parentCategoryField,
                ),
                initialValue: _selectedCategoryId,
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
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              AppInput(
                label: l10n.priceInCentsField,
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              AppInput(
                label: l10n.costInCentsField,
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 8),
              ProductFlagsSection(
                isActive: _isActive,
                isAvailableInPos: _isAvailableInPos,
                isRawMaterial: _isRawMaterial,
                tracksInventory: _tracksInventory,
                onActiveChanged: (value) {
                  setState(() => _isActive = value);
                },
                onAvailableInPosChanged: (value) {
                  setState(() => _isAvailableInPos = value);
                },
                onRawMaterialChanged: (value) {
                  setState(() {
                    _isRawMaterial = value;
                    if (value) _isAvailableInPos = false;
                  });
                },
                onTracksInventoryChanged: (value) {
                  setState(() => _tracksInventory = value);
                },
              ),
              ModifierGroupSelector(
                groups: _activeModifierGroups,
                selectedIds: _selectedModifierGroupIds,
                onChanged: (groupId, {required selected}) {
                  setState(() {
                    if (selected) {
                      _selectedModifierGroupIds.add(groupId);
                    } else {
                      _selectedModifierGroupIds.remove(groupId);
                    }
                    _error = null;
                  });
                },
              ),
              if (_error != null) AppText(_error!, maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l10n.cancelAction,
          onPressed: () => Navigator.of(context).pop(),
          primary: false,
        ),
        AppButton(label: l10n.saveAction, onPressed: _submit),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final parsedPrice = MoneyFormatter.parseToCents(_priceController.text);
    final cost = MoneyFormatter.parseToCents(_costController.text);
    final price = _isRawMaterial ? (parsedPrice ?? 0) : parsedPrice;

    if (name.isEmpty || _selectedCategoryId == null) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    if (price == null || cost == null) {
      setState(() => _error = l10n.numericFieldError);
      return;
    }

    if (!_isRawMaterial && price <= 0) {
      setState(() => _error = l10n.sellableProductPriceRequiredError);
      return;
    }

    Navigator.of(context).pop(
      Product(
        id: widget.product?.id ?? const Uuid().v4(),
        categoryId: _selectedCategoryId!,
        name: name,
        priceInCents: price,
        costInCents: cost,
        isActive: _isActive,
        isAvailableInPos: !_isRawMaterial && _isAvailableInPos,
        isRawMaterial: _isRawMaterial,
        tracksInventory: _tracksInventory,
        optionGroups: widget.product?.optionGroups ?? const [],
        modifierGroupIds: _selectedModifierGroupIds.toList(),
      ),
    );
  }

  List<ModifierGroup> get _activeModifierGroups {
    final groups =
        widget.modifierGroups.where((group) {
          return group.isActive || _selectedModifierGroupIds.contains(group.id);
        }).toList()..sort((first, second) {
          final order = first.displayOrder.compareTo(second.displayOrder);
          if (order != 0) return order;
          return first.name.compareTo(second.name);
        });

    return groups;
  }

  List<ProductCategory> get _activeCategories {
    final categories = widget.categories.where((category) {
      return category.isActive || category.id == _selectedCategoryId;
    }).toList();

    return _orderedCategories(categories);
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

  List<ProductCategory> _orderedCategories(List<ProductCategory> categories) {
    final ordered = <ProductCategory>[];

    void addChildren(String? parentId) {
      final children =
          categories.where((category) => category.parentId == parentId).toList()
            ..sort(
              (first, second) => first.sortOrder.compareTo(second.sortOrder),
            );

      for (final child in children) {
        ordered.add(child);
        addChildren(child.id);
      }
    }

    addChildren(null);
    for (final category in categories) {
      if (!ordered.any((item) => item.id == category.id)) {
        ordered.add(category);
      }
    }

    return ordered;
  }

  ProductCategory? _categoryById(String id) {
    for (final category in widget.categories) {
      if (category.id == id) return category;
    }

    return null;
  }
}
