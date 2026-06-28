import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_option.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Dialog for creating or editing a modifier group.
class ModifierGroupDialog extends StatefulWidget {
  /// Creates a group dialog.
  const ModifierGroupDialog({this.group, super.key});

  /// Group being edited.
  final ModifierGroup? group;

  @override
  State<ModifierGroupDialog> createState() => _ModifierGroupDialogState();
}

class _ModifierGroupDialogState extends State<ModifierGroupDialog> {
  final _nameController = TextEditingController();
  bool _isActive = true;
  bool _isRequired = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    if (group == null) return;
    _nameController.text = group.name;
    _isActive = group.isActive;
    _isRequired = group.isRequired;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: AppText(
        widget.group == null
            ? l10n.createModifierGroupTitle
            : l10n.editModifierGroupTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(label: l10n.nameField, controller: _nameController),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(l10n.optionGroupRequiredField),
              value: _isRequired,
              onChanged: (value) => setState(() => _isRequired = value ?? true),
            ),
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
    if (name.isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    Navigator.of(context).pop(
      ModifierGroup(
        id: widget.group?.id ?? const Uuid().v4(),
        name: name,
        isRequired: _isRequired,
        displayOrder: widget.group?.displayOrder ?? 0,
        isActive: _isActive,
      ),
    );
  }
}

/// Dialog for creating or editing a modifier option.
class ModifierOptionDialog extends StatefulWidget {
  /// Creates an option dialog.
  const ModifierOptionDialog({
    required this.group,
    this.option,
    super.key,
  });

  /// Parent group.
  final ModifierGroup group;

  /// Option being edited.
  final ModifierOption? option;

  @override
  State<ModifierOptionDialog> createState() => _ModifierOptionDialogState();
}

class _ModifierOptionDialogState extends State<ModifierOptionDialog> {
  final _nameController = TextEditingController();
  bool _isActive = true;
  bool _isAvailableInPos = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final option = widget.option;
    if (option == null) return;
    _nameController.text = option.name;
    _isActive = option.isActive;
    _isAvailableInPos = option.isAvailableInPos;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: AppText(
        widget.option == null
            ? l10n.createModifierOptionTitle
            : l10n.editModifierOptionTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(widget.group.name, variant: AppTextVariant.label),
            AppInput(label: l10n.nameField, controller: _nameController),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(l10n.activeField),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(l10n.availableInPosField),
              value: _isAvailableInPos,
              onChanged: (value) {
                setState(() => _isAvailableInPos = value ?? true);
              },
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
    if (name.isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    Navigator.of(context).pop(
      ModifierOption(
        id: widget.option?.id ?? const Uuid().v4(),
        groupId: widget.group.id,
        name: name,
        priceDeltaInCents: widget.option?.priceDeltaInCents ?? 0,
        displayOrder: widget.option?.displayOrder ?? 0,
        isActive: _isActive,
        isAvailableInPos: _isAvailableInPos,
      ),
    );
  }
}
