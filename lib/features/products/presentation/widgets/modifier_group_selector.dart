import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Selector for reusable POS modifier groups assigned to a product.
class ModifierGroupSelector extends StatelessWidget {
  /// Creates the selector.
  const ModifierGroupSelector({
    required this.groups,
    required this.onChanged,
    required this.selectedIds,
    super.key,
  });

  /// Available modifier groups.
  final List<ModifierGroup> groups;

  /// Selected group ids.
  final Set<String> selectedIds;

  /// Selection change callback.
  final void Function(String groupId, {required bool selected}) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        AppText(
          l10n.productModifierGroupsField,
          variant: AppTextVariant.titleMedium,
        ),
        const SizedBox(height: 4),
        if (groups.isEmpty)
          AppText(
            l10n.productModifierGroupsEmptyMessage,
            maxLines: 2,
            variant: AppTextVariant.label,
          )
        else
          for (final group in groups)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(group.name),
              subtitle: AppText(
                group.isRequired
                    ? l10n.optionGroupRequiredField
                    : l10n.optionalField,
                variant: AppTextVariant.label,
              ),
              value: selectedIds.contains(group.id),
              onChanged: (value) => onChanged(
                group.id,
                selected: value ?? false,
              ),
            ),
      ],
    );
  }
}
