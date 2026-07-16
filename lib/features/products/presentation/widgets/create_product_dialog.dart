import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/presentation/widgets/modifier_group_selector.dart';
import 'package:smoo_control/features/products/presentation/widgets/product_category_dropdown.dart';
import 'package:smoo_control/features/products/presentation/widgets/product_flags_section.dart';
import 'package:smoo_control/features/products/presentation/widgets/product_units_section.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Dialog used to create a product.
class CreateProductDialog extends StatefulWidget {
  /// Creates the product dialog.
  const CreateProductDialog({
    required this.categories,
    required this.modifierGroups,
    this.units = const [],
    this.product,
    super.key,
  });

  /// Categories and subcategories available for product assignment.
  final List<ProductCategory> categories;

  /// Reusable modifier groups available for assignment.
  final List<ModifierGroup> modifierGroups;

  /// Units available for inventory and purchases.
  final List<MeasurementUnit> units;

  /// Product being edited.
  final Product? product;

  @override
  State<CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends State<CreateProductDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController(text: '0');
  final _purchaseFactorController = TextEditingController(text: '1');
  bool _isActive = true;
  bool _isAvailableInPos = true;
  bool _isRawMaterial = false;
  bool _usesRecipe = false;
  bool _tracksInventory = false;
  String? _error;
  String? _selectedCategoryId;
  String? _purchaseUnitId;
  String? _inventoryUnitId;
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
    _usesRecipe = product.usesRecipe;
    _tracksInventory = product.tracksInventory;
    _purchaseUnitId = product.purchaseUnitId;
    _inventoryUnitId = product.inventoryUnitId;
    final factor = product.purchaseToInventoryFactor;
    if (factor != null) _purchaseFactorController.text = factor.toString();
    _selectedModifierGroupIds.addAll(product.modifierGroupIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _purchaseFactorController.dispose();
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
              ProductCategoryDropdown(
                categories: widget.categories,
                selectedCategoryId: _selectedCategoryId,
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
                usesRecipe: _usesRecipe,
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
                    if (value) {
                      _isAvailableInPos = false;
                      _usesRecipe = false;
                    }
                  });
                },
                onUsesRecipeChanged: (value) {
                  setState(() => _usesRecipe = value);
                },
                onTracksInventoryChanged: (value) {
                  setState(() => _tracksInventory = value);
                },
              ),
              if (_isRawMaterial)
                ProductUnitsSection(
                  units: widget.units,
                  purchaseUnitId: _purchaseUnitId,
                  inventoryUnitId: _inventoryUnitId,
                  purchaseFactorController: _purchaseFactorController,
                  onPurchaseUnitChanged: (value) {
                    setState(() => _purchaseUnitId = value);
                  },
                  onInventoryUnitChanged: (value) {
                    setState(() => _inventoryUnitId = value);
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
    final purchaseFactor = double.tryParse(
      _purchaseFactorController.text.trim(),
    );

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

    if (_isRawMaterial &&
        widget.units.isNotEmpty &&
        (_purchaseUnitId == null ||
            _inventoryUnitId == null ||
            purchaseFactor == null ||
            purchaseFactor <= 0)) {
      setState(() => _error = l10n.productUnitsRequiredError);
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
        usesRecipe: !_isRawMaterial && _usesRecipe,
        tracksInventory: _tracksInventory,
        purchaseUnitId: _isRawMaterial ? _purchaseUnitId : null,
        inventoryUnitId: _isRawMaterial ? _inventoryUnitId : null,
        purchaseToInventoryFactor: _isRawMaterial ? purchaseFactor : null,
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
}
