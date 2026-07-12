import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/theme/app_semantic_colors.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

part 'modifier_group_actions.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;
        return ExpansionTile(
          leading: const Icon(Icons.tune_outlined),
          subtitle: AppText(
            isCompact
                ? '${_optionsCountLabel(l10n)} - ${_groupStatusLabel(l10n)}'
                : _groupStatusLabel(l10n),
            maxLines: isCompact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.label,
          ),
          title: AppText(
            group.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isCompact
              ? _GroupPopupActions(
                  isActive: group.isActive,
                  onAddOption: onAddOption,
                  onDeactivateGroup: onDeactivateGroup,
                  onEditGroup: onEditGroup,
                )
              : _GroupActions(
                  isActive: group.isActive,
                  onAddOption: onAddOption,
                  onDeactivateGroup: onDeactivateGroup,
                  onEditGroup: onEditGroup,
                  optionsLabel: _optionsCountLabel(l10n),
                ),
          children: [
            for (final option in options)
              ListTile(
                contentPadding: EdgeInsetsDirectional.only(
                  start: isCompact ? 32 : 56,
                  end: 16,
                ),
                leading: const Icon(Icons.restaurant_menu_outlined),
                subtitle: AppText(
                  _optionStatusLabel(l10n, option),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  variant: AppTextVariant.label,
                ),
                title: AppText(
                  option.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isCompact
                    ? _OptionPopupActions(
                        isActive: option.isActive,
                        onDeactivate: () => onDeactivateOption(option),
                        onEdit: () => onEditOption(option),
                      )
                    : _OptionActions(
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
      },
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
