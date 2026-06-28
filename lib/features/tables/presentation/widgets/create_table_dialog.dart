import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Dialog used to create a restaurant table.
class CreateTableDialog extends StatefulWidget {
  /// Creates the table dialog.
  const CreateTableDialog({this.table, super.key});

  /// Table being edited.
  final RestaurantTable? table;

  @override
  State<CreateTableDialog> createState() => _CreateTableDialogState();
}

class _CreateTableDialogState extends State<CreateTableDialog> {
  final _nameController = TextEditingController();
  bool _isActive = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final table = widget.table;
    if (table == null) {
      return;
    }

    _nameController.text = table.name;
    _isActive = table.isActive;
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
        widget.table == null ? l10n.createTableTitle : l10n.editTableTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(label: l10n.nameField, controller: _nameController),
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

    if (name.isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    Navigator.of(context).pop(
      RestaurantTable(
        id: widget.table?.id ?? const Uuid().v4(),
        name: name,
        status: _statusForSave(),
        isActive: _isActive,
      ),
    );
  }

  RestaurantTableStatus _statusForSave() {
    final currentStatus =
        widget.table?.status ?? RestaurantTableStatus.available;
    if (!_isActive) return RestaurantTableStatus.disabled;
    if (currentStatus == RestaurantTableStatus.disabled) {
      return RestaurantTableStatus.available;
    }

    return currentStatus;
  }
}
