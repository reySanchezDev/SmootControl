import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Dialog that asks required product options before adding it to the cart.
class ProductOptionsDialog extends StatefulWidget {
  /// Creates a product options dialog.
  const ProductOptionsDialog({
    required this.product,
    required this.optionGroups,
    super.key,
  });

  /// Product being configured for the cart.
  final Product product;

  /// Resolved groups to request.
  final List<ProductOptionGroup> optionGroups;

  @override
  State<ProductOptionsDialog> createState() => _ProductOptionsDialogState();
}

class _ProductOptionsDialogState extends State<ProductOptionsDialog> {
  final _selectedByGroup = <String, String>{};
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = widget.optionGroups;
    final group = groups[_currentIndex];
    final isLast = _currentIndex == widget.optionGroups.length - 1;
    final selected = _selectedByGroup[group.name];
    final canConfirm = selected != null || !group.isRequired;
    final showConfirm = !isLast || (selected == null && !group.isRequired);
    final confirmLabel = selected == null && !group.isRequired
        ? l10n.skipOptionalOptionAction
        : l10n.nextAction;

    return AlertDialog(
      title: AppText(
        l10n.selectProductOptionsTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(widget.product.name, variant: AppTextVariant.label),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentIndex + 1) / groups.length,
              ),
              const SizedBox(height: 8),
              AppText(
                '${_currentIndex + 1}/${groups.length}',
                textAlign: TextAlign.end,
                variant: AppTextVariant.label,
              ),
              const SizedBox(height: 8),
              AppText(
                group.name,
                textAlign: TextAlign.center,
                variant: AppTextVariant.titleMedium,
              ),
              const SizedBox(height: 12),
              _OptionGrid(
                options: group.options,
                selectedOption: selected,
                onSelected: (option) => _selectOption(group, option),
              ),
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
        if (_currentIndex > 0)
          AppButton(
            label: l10n.previousAction,
            onPressed: _previousStep,
            primary: false,
          ),
        if (showConfirm)
          AppButton(
            label: confirmLabel,
            onPressed: canConfirm ? _confirmStep : null,
          ),
      ],
    );
  }

  void _selectOption(ProductOptionGroup group, String option) {
    final isLast = _currentIndex == widget.optionGroups.length - 1;
    _selectedByGroup[group.name] = option;
    if (isLast) {
      _finishSelection();
      return;
    }
    setState(() => _currentIndex += 1);
  }

  void _previousStep() {
    if (_currentIndex == 0) return;
    setState(() => _currentIndex -= 1);
  }

  void _confirmStep() {
    final isLast = _currentIndex == widget.optionGroups.length - 1;
    if (!isLast) {
      setState(() => _currentIndex += 1);
      return;
    }

    _finishSelection();
  }

  void _finishSelection() {
    final selections = [
      for (final group in widget.optionGroups)
        if (_selectedByGroup[group.name] case final option?)
          SelectedProductOption(groupName: group.name, optionName: option),
    ];

    Navigator.of(context).pop(selections);
  }
}

class _OptionGrid extends StatelessWidget {
  const _OptionGrid({
    required this.onSelected,
    required this.options,
    required this.selectedOption,
  });

  final ValueChanged<String> onSelected;
  final List<String> options;
  final String? selectedOption;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth < 420 ? 140.0 : 180.0;

        return Wrap(
          runSpacing: 10,
          spacing: 10,
          children: [
            for (final option in options)
              _OptionTile(
                isSelected: selectedOption == option,
                label: option,
                onTap: () => onSelected(option),
                width: tileWidth,
              ),
          ],
        );
      },
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.isSelected,
    required this.label,
    required this.onTap,
    required this.width,
  });

  final bool isSelected;
  final String label;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 88,
      width: width,
      child: Material(
        borderRadius: BorderRadius.circular(8),
        color: isSelected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AppText(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                variant: AppTextVariant.titleMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
