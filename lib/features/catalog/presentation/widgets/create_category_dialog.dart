import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Dialog used to create a category or subcategory.
class CreateCategoryDialog extends StatefulWidget {
  /// Creates the category dialog.
  const CreateCategoryDialog({
    required this.categories,
    this.category,
    super.key,
  });

  /// Existing categories used to select a parent and calculate ordering.
  final List<ProductCategory> categories;

  /// Category being edited.
  final ProductCategory? category;

  @override
  State<CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<CreateCategoryDialog> {
  static const _rootParentValue = '__root__';

  final _nameController = TextEditingController();
  final _positionController = TextEditingController();
  bool _isActive = true;
  String? _error;
  String? _selectedParentId;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    if (category == null) {
      return;
    }

    _nameController.text = category.name;
    _positionController.text = category.sortOrder.toString();
    _isActive = category.isActive;
    _selectedParentId = category.parentId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.category == null && _positionController.text.isEmpty) {
      _positionController.text = _nextSortOrder(_selectedParentId).toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parentOptions = _parentOptions();

    return AlertDialog(
      title: AppText(
        widget.category == null
            ? l10n.createCategoryTitle
            : l10n.editCategoryTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(label: l10n.nameField, controller: _nameController),
            const SizedBox(height: 12),
            AppInput(
              label: 'Posicion POS',
              controller: _positionController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: l10n.catalogParentField),
              initialValue: _selectedParentId ?? _rootParentValue,
              items: [
                DropdownMenuItem(
                  value: _rootParentValue,
                  child: AppText(l10n.rootCategoryOption),
                ),
                for (final option in parentOptions)
                  DropdownMenuItem(
                    value: option.id,
                    child: AppText(
                      _parentLabel(option),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedParentId = value == _rootParentValue ? null : value;
                  _positionController.text = _sortOrderFor(
                    _selectedParentId,
                  ).toString();
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(l10n.activeField),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value ?? true),
            ),
            if (_error != null) AppText(_error!, maxLines: 2),
          ],
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
    final parentId = _selectedParentId;
    final position = int.tryParse(_positionController.text.trim());

    if (name.isEmpty || _positionController.text.trim().isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    if (position == null || position < 1) {
      setState(() => _error = l10n.numericFieldError);
      return;
    }

    Navigator.of(context).pop(
      ProductCategory(
        id: widget.category?.id ?? const Uuid().v4(),
        name: name,
        parentId: parentId,
        sortOrder: position,
        isActive: _isActive,
      ),
    );
  }

  int _sortOrderFor(String? parentId) {
    final category = widget.category;
    if (category != null && category.parentId == parentId) {
      return category.sortOrder;
    }

    return _nextSortOrder(parentId);
  }

  int _nextSortOrder(String? parentId) {
    final siblings = widget.categories.where((category) {
      return category.id != widget.category?.id &&
          category.parentId == parentId;
    }).toList();

    if (siblings.isEmpty) {
      return 1;
    }

    return siblings
            .map((category) => category.sortOrder)
            .reduce((value, element) => value > element ? value : element) +
        1;
  }

  List<ProductCategory> _parentOptions() {
    final options = widget.categories.where((category) {
      final editedId = widget.category?.id;
      if (category.id == editedId) return false;
      if (editedId != null && _isDescendantOf(category.id, editedId)) {
        return false;
      }
      return category.isActive || category.id == _selectedParentId;
    }).toList();

    return _orderedCategories(options);
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

  bool _isDescendantOf(String categoryId, String ancestorId) {
    var currentId = categoryId;
    final visited = <String>{};

    while (visited.add(currentId)) {
      final category = _categoryById(currentId);
      final parentId = category?.parentId;
      if (parentId == null) return false;
      if (parentId == ancestorId) return true;
      currentId = parentId;
    }

    return false;
  }

  ProductCategory? _categoryById(String id) {
    for (final category in widget.categories) {
      if (category.id == id) return category;
    }

    return null;
  }

  String _parentLabel(ProductCategory category) {
    final depth = _depthFor(category);
    final indentation = List.filled(depth, '  ').join();
    final prefix = depth == 0 ? '' : '$indentation- ';

    return '$prefix${category.name}';
  }

  int _depthFor(ProductCategory category) {
    var depth = 0;
    var parentId = category.parentId;
    final visited = <String>{category.id};

    while (parentId != null && visited.add(parentId)) {
      depth += 1;
      parentId = _categoryById(parentId)?.parentId;
    }

    return depth;
  }
}
