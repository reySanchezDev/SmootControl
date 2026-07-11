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

enum _GroupAction { add, deactivate, edit }

class _GroupPopupActions extends StatelessWidget {
  const _GroupPopupActions({
    required this.isActive,
    required this.onAddOption,
    required this.onDeactivateGroup,
    required this.onEditGroup,
  });

  final bool isActive;
  final VoidCallback onAddOption;
  final VoidCallback onDeactivateGroup;
  final VoidCallback onEditGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_GroupAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _GroupAction.add:
            onAddOption();
          case _GroupAction.deactivate:
            onDeactivateGroup();
          case _GroupAction.edit:
            onEditGroup();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _GroupAction.add,
          child: _PopupActionLabel(
            icon: Icons.add,
            label: l10n.addModifierOptionAction,
          ),
        ),
        if (isActive)
          PopupMenuItem(
            value: _GroupAction.deactivate,
            child: _PopupActionLabel(
              icon: Icons.delete_outline,
              label: l10n.deactivateAction,
            ),
          ),
        PopupMenuItem(
          value: _GroupAction.edit,
          child: _PopupActionLabel(
            icon: Icons.edit_outlined,
            label: l10n.editAction,
          ),
        ),
      ],
      tooltip: l10n.moreOptionsAction,
    );
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

enum _OptionAction { deactivate, edit }

class _OptionPopupActions extends StatelessWidget {
  const _OptionPopupActions({
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
    return PopupMenuButton<_OptionAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _OptionAction.deactivate:
            onDeactivate();
          case _OptionAction.edit:
            onEdit();
        }
      },
      itemBuilder: (context) => [
        if (isActive)
          PopupMenuItem(
            value: _OptionAction.deactivate,
            child: _PopupActionLabel(
              icon: Icons.delete_outline,
              label: l10n.deactivateAction,
            ),
          ),
        PopupMenuItem(
          value: _OptionAction.edit,
          child: _PopupActionLabel(
            icon: Icons.edit_outlined,
            label: l10n.editAction,
          ),
        ),
      ],
      tooltip: l10n.moreOptionsAction,
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

class _PopupActionLabel extends StatelessWidget {
  const _PopupActionLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: AppText(label)),
      ],
    );
  }
}
