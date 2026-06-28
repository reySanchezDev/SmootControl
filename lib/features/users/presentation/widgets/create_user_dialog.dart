import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/roles/domain/entities/access_role.dart';
import 'package:smoo_control/features/roles/domain/services/default_access_roles.dart';
import 'package:smoo_control/features/users/domain/entities/app_user_profile.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Result returned by the user dialog.
final class CreateUserDialogResult {
  /// Creates a user dialog result.
  const CreateUserDialogResult({
    required this.user,
    this.pin,
  });

  /// User profile to save.
  final AppUserProfile user;

  /// Optional new local access PIN.
  final String? pin;
}

/// Dialog used to create or edit a user.
class CreateUserDialog extends StatefulWidget {
  /// Creates the user dialog.
  const CreateUserDialog({
    required this.roles,
    this.user,
    super.key,
  });

  /// User being edited.
  final AppUserProfile? user;

  /// Assignable roles.
  final List<AccessRole> roles;

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isActive = true;
  bool _isPosUser = false;
  String? _roleId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (user == null) {
      final activeRoles = _activeRoles;
      _roleId = activeRoles.isEmpty ? null : activeRoles.first.id;
      _isPosUser = _isPosRole(_roleId);
      return;
    }
    _nameController.text = user.displayName;
    _emailController.text = user.email;
    _roleId = user.roleId;
    _isPosUser = user.isPosUser;
    _isActive = user.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  List<AccessRole> get _activeRoles {
    return widget.roles.where((role) => role.isActive).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: AppText(
        widget.user == null ? l10n.createUserTitle : l10n.editUserTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(label: l10n.displayNameField, controller: _nameController),
            const SizedBox(height: 12),
            AppInput(label: l10n.emailField, controller: _emailController),
            const SizedBox(height: 12),
            AppInput(
              label: widget.user == null
                  ? l10n.pinField
                  : l10n.pinOptionalField,
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: l10n.roleField),
              initialValue: _roleId,
              isExpanded: true,
              items: [
                for (final role in _activeRoles)
                  DropdownMenuItem(value: role.id, child: AppText(role.name)),
              ],
              onChanged: (value) => setState(() {
                _roleId = value;
                if (_isPosRole(value)) {
                  _isPosUser = true;
                }
              }),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(l10n.posUserField),
              subtitle: AppText(l10n.posUserHelp, maxLines: 2),
              value: _isPosUser,
              onChanged: (value) => setState(() {
                _isPosUser = value ?? false;
              }),
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
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();
    final roleId = _roleId;

    if (name.isEmpty ||
        email.isEmpty ||
        roleId == null ||
        (widget.user == null && pin.isEmpty)) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    Navigator.of(context).pop(
      CreateUserDialogResult(
        pin: pin.isEmpty ? null : pin,
        user: AppUserProfile(
          id: widget.user?.id ?? const Uuid().v4(),
          displayName: name,
          email: email,
          roleId: roleId,
          pinSalt: widget.user?.pinSalt,
          pinHash: widget.user?.pinHash,
          isPosUser: _isPosUser,
          isActive: _isActive,
        ),
      ),
    );
  }

  bool _isPosRole(String? roleId) {
    return roleId == DefaultAccessRoles.cashierId ||
        roleId == DefaultAccessRoles.waiterId;
  }
}
