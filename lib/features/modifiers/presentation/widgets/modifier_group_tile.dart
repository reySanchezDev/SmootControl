import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/theme/app_semantic_colors.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Expandable tile that shows a modifier group and its options.
class ModifierGroupTile extends StatelessWidget {
  /// Creates the tile.
  const ModifierGroupTile({
    required this.group,
    required this.onAddOption,
    required this.onDeactivateGroup,
    required this.onDeactivateOption,
    required this.onEditGroup,
    required this.onEditOption,
    required this.options,
    super.key,
  });

  /// Modifier group shown as the parent row.
  final ModifierGroup group;

  /// Adds an option under [group].
  final VoidCallback onAddOption;

  /// Deactivates [group].
  final VoidCallback onDeactivateGroup;

  /// Deactivates an option.
  final ValueChanged<ModifierOption> onDeactivateOption;

  /// Edits [group].
  final VoidCallback onEditGroup;

  /// Edits an option.
  final ValueChanged<ModifierOption> onEditOption;

  /// Options that belong to [group].
  final List<ModifierOption> options;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExpansionTile(
      leading: const Icon(Icons.tune_outlined),
      subtitle: AppText(
        _groupStatusLabel(l10n),
        variant: AppTextVariant.label,
      ),
      title: AppText(group.name),
      trailing: _GroupActions(
        isActive: group.isActive,
        onAddOption: onAddOption,
        onDeactivateGroup: onDeactivateGroup,
        onEditGroup: onEditGroup,
        optionsLabel: _optionsCountLabel(l10n),
      ),
      children: [
        for (final option in options)
          ListTile(
            leading: const Icon(Icons.restaurant_menu_outlined),
            subtitle: AppText(
              _optionStatusLabel(l10n, option),
              variant: AppTextVariant.label,
            ),
            title: AppText(option.name),
            trailing: _OptionActions(
              isActive: option.isActive,
              onDeactivate: () => onDeactivateOption(option),
              onEdit: () => onEditOption(option),
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: AppText(l10n.addModifierOptionAction),
          onPressed: onAddOption,
        ),
      ],
    );
  }

  String _groupStatusLabel(AppLocalizations l10n) {
    final requiredLabel = group.isRequired
        ? l10n.optionGroupRequiredField
        : l10n.optionalField;
    final activeLabel = group.isActive
        ? l10n.activeStatus
        : l10n.inactiveStatus;
    return '$requiredLabel - $activeLabel';
  }

  String _optionStatusLabel(AppLocalizations l10n, ModifierOption option) {
    final activeLabel = option.isActive
        ? l10n.activeStatus
        : l10n.inactiveStatus;
    final availableLabel = option.isAvailableInPos
        ? l10n.availableInPosStatus
        : l10n.unavailableInPosStatus;
    return '$activeLabel - $availableLabel';
  }

  String _optionsCountLabel(AppLocalizations l10n) {
    final count = options.length;
    if (count == 0) return l10n.modifierGroupNoOptions;
    if (count == 1) return l10n.modifierGroupOneOption;
    return l10n.modifierGroupManyOptions(count);
  }
}

class _GroupActions extends StatelessWidget {
  const _GroupActions({
    required this.isActive,
    required this.onAddOption,
    required this.onDeactivateGroup,
    required this.onEditGroup,
    required this.optionsLabel,
  });

  final bool isActive;
  final VoidCallback onAddOption;
  final VoidCallback onDeactivateGroup;
  final VoidCallback onEditGroup;
  final String optionsLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semanticColors = context.semanticColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(optionsLabel, variant: AppTextVariant.label),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onAddOption,
          tooltip: l10n.addModifierOptionAction,
        ),
        if (isActive)
          IconButton(
            color: semanticColors.dangerAction,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDeactivateGroup,
            tooltip: l10n.deactivateAction,
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEditGroup,
          tooltip: l10n.editAction,
        ),
      ],
    );
  }
}

class _OptionActions extends StatelessWidget {
  const _OptionActions({
    required this.isActive,
    required this.onDeactivate,
    required this.onEdit,
  });

  final bool isActive;
  final VoidCallback onDeactivate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semanticColors = context.semanticColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isActive)
          IconButton(
            color: semanticColors.dangerAction,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDeactivate,
            tooltip: l10n.deactivateAction,
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          tooltip: l10n.editAction,
        ),
      ],
    );
  }
}
