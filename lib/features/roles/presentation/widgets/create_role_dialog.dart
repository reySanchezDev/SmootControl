import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/roles/domain/entities/access_permission.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Dialog used to create or edit a role.
class CreateRoleDialog extends StatefulWidget {
  /// Creates the role dialog.
  const CreateRoleDialog({
    required this.permissions,
    required this.selectedPermissionCodes,
    this.role,
    super.key,
  });

  /// Role being edited.
  final AccessRole? role;

  /// Available permission catalog.
  final List<AccessPermission> permissions;

  /// Current selected permission codes.
  final List<String> selectedPermissionCodes;

  @override
  State<CreateRoleDialog> createState() => _CreateRoleDialogState();
}

class _CreateRoleDialogState extends State<CreateRoleDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedCodes = {};
  bool _isActive = true;
  bool _isSystem = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    _selectedCodes.addAll(widget.selectedPermissionCodes);
    if (role == null) return;
    _nameController.text = role.name;
    _descriptionController.text = role.description ?? '';
    _isActive = role.isActive;
    _isSystem = role.isSystem;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: AppText(
        widget.role == null ? l10n.createRoleTitle : l10n.editRoleTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInput(label: l10n.nameField, controller: _nameController),
              const SizedBox(height: 12),
              AppInput(
                label: l10n.roleDescriptionField,
                controller: _descriptionController,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: AppText(l10n.systemRoleField),
                value: _isSystem,
                onChanged: (value) =>
                    setState(() => _isSystem = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: AppText(l10n.activeField),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value ?? true),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: AppText(
                  l10n.permissionsSection,
                  variant: AppTextVariant.titleMedium,
                ),
              ),
              for (final permission in widget.permissions)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: AppText(permission.name),
                  value: _selectedCodes.contains(permission.code),
                  onChanged: (value) =>
                      _togglePermission(permission.code, value),
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

  void _togglePermission(String code, bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedCodes.add(code);
      } else {
        _selectedCodes.remove(code);
      }
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    Navigator.of(context).pop(
      RoleDialogResult(
        role: AccessRole(
          id: widget.role?.id ?? const Uuid().v4(),
          name: name,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isSystem: _isSystem,
          isActive: _isActive,
        ),
        permissionCodes: _selectedCodes.toList()..sort(),
      ),
    );
  }
}

/// Result returned by [CreateRoleDialog].
final class RoleDialogResult {
  /// Creates a role dialog result.
  const RoleDialogResult({
    required this.role,
    required this.permissionCodes,
  });

  /// Saved role.
  final AccessRole role;

  /// Selected permission codes.
  final List<String> permissionCodes;
}
