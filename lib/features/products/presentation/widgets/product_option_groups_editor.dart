import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';
import 'package:smoo_control/features/products/presentation/widgets/product_option_groups_editor_value.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'product_option_groups_editor_draft.dart';

/// Editor for product option groups without exposing technical fields.
class ProductOptionGroupsEditor extends StatefulWidget {
  /// Creates a product option groups editor.
  const ProductOptionGroupsEditor({
    required this.initialGroups,
    required this.onChanged,
    super.key,
  });

  /// Groups already configured for the product.
  final List<ProductOptionGroup> initialGroups;

  /// Emits the current editor value.
  final ValueChanged<ProductOptionGroupsEditorValue> onChanged;

  @override
  State<ProductOptionGroupsEditor> createState() =>
      ProductOptionGroupsEditorState();
}

/// State that exposes the current editor value to the parent form.
class ProductOptionGroupsEditorState extends State<ProductOptionGroupsEditor> {
  late final List<_OptionGroupDraft> _groups;

  @override
  void initState() {
    super.initState();
    _groups = [
      for (final group in widget.initialGroups) _OptionGroupDraft.from(group),
    ];
  }

  @override
  void dispose() {
    for (final group in _groups) {
      group.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                l10n.productOptionGroupsField,
                variant: AppTextVariant.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addGroup,
              tooltip: l10n.addOptionGroupAction,
            ),
          ],
        ),
        if (_groups.isEmpty)
          AppText(
            l10n.productOptionGroupsEmptyMessage,
            maxLines: 2,
            variant: AppTextVariant.label,
          ),
        for (var index = 0; index < _groups.length; index += 1) ...[
          const SizedBox(height: 8),
          _OptionGroupEditor(
            draft: _groups[index],
            groupNumber: index + 1,
            onAddOption: () => _addOption(index),
            onChanged: _notifyChanged,
            onRemoveGroup: () => _removeGroup(index),
            onRemoveOption: (optionIndex) => _removeOption(index, optionIndex),
            onRequiredChanged: (value) => _setRequired(index, value),
          ),
        ],
        const SizedBox(height: 8),
        AppButton(
          icon: Icons.add,
          label: l10n.addOptionGroupAction,
          onPressed: _addGroup,
          primary: false,
        ),
      ],
    );
  }

  void _addGroup() {
    setState(() => _groups.add(_OptionGroupDraft.empty()));
    _notifyChanged();
  }

  void _removeGroup(int index) {
    setState(() => _groups.removeAt(index).dispose());
    _notifyChanged();
  }

  void _addOption(int groupIndex) {
    setState(() => _groups[groupIndex].optionControllers.add(_controller()));
    _notifyChanged();
  }

  void _removeOption(int groupIndex, int optionIndex) {
    final group = _groups[groupIndex];
    setState(() => group.optionControllers.removeAt(optionIndex).dispose());
    _notifyChanged();
  }

  void _setRequired(int groupIndex, bool value) {
    setState(() => _groups[groupIndex].isRequired = value);
    _notifyChanged();
  }

  void _notifyChanged() {
    widget.onChanged(_editorValue());
  }

  /// Reads the latest text controller values.
  ProductOptionGroupsEditorValue currentValue() => _editorValue();

  ProductOptionGroupsEditorValue _editorValue() {
    final groups = <ProductOptionGroup>[];
    var hasInvalidInput = false;

    for (final draft in _groups) {
      final value = draft.toValue();
      if (value == null) continue;
      hasInvalidInput = hasInvalidInput || value.hasInvalidInput;
      if (value.group != null) groups.add(value.group!);
    }

    return ProductOptionGroupsEditorValue(
      groups: groups,
      hasInvalidInput: hasInvalidInput,
    );
  }
}

class _OptionGroupEditor extends StatelessWidget {
  const _OptionGroupEditor({
    required this.draft,
    required this.groupNumber,
    required this.onAddOption,
    required this.onChanged,
    required this.onRemoveGroup,
    required this.onRemoveOption,
    required this.onRequiredChanged,
  });

  final _OptionGroupDraft draft;
  final int groupNumber;
  final VoidCallback onAddOption;
  final VoidCallback onChanged;
  final VoidCallback onRemoveGroup;
  final ValueChanged<int> onRemoveOption;
  final ValueChanged<bool> onRequiredChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = draft.toValue();
    final hasInvalidInput = value?.hasInvalidInput ?? false;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(
                    '${l10n.optionGroupNameField} $groupNumber',
                    variant: AppTextVariant.label,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemoveGroup,
                  tooltip: l10n.removeAction,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    label: l10n.optionGroupNameField,
                    controller: draft.nameController,
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
            if (hasInvalidInput)
              Align(
                alignment: Alignment.centerLeft,
                child: AppText(
                  l10n.productOptionGroupsFormatError,
                  maxLines: 2,
                  variant: AppTextVariant.label,
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(l10n.optionGroupRequiredField),
              value: draft.isRequired,
              onChanged: (value) => onRequiredChanged(value ?? true),
            ),
            const SizedBox(height: 8),
            for (
              var index = 0;
              index < draft.optionControllers.length;
              index += 1
            ) ...[
              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      label: '${l10n.productOptionField} ${index + 1}',
                      controller: draft.optionControllers[index],
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => onRemoveOption(index),
                    tooltip: l10n.removeAction,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.addOptionAction),
                onPressed: onAddOption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
