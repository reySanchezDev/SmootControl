import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/payment_methods/domain/services/payment_method_tree_service.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Dialog used to create a payment method.
class CreatePaymentMethodDialog extends StatefulWidget {
  /// Creates the payment method dialog.
  const CreatePaymentMethodDialog({
    this.method,
    this.methods = const [],
    super.key,
  });

  /// Payment method being edited.
  final PaymentMethod? method;

  /// Existing methods used to select a parent.
  final List<PaymentMethod> methods;

  @override
  State<CreatePaymentMethodDialog> createState() =>
      _CreatePaymentMethodDialogState();
}

class _CreatePaymentMethodDialogState extends State<CreatePaymentMethodDialog> {
  final _currencyController = TextEditingController();
  final _nameController = TextEditingController();
  bool _affectsCashRegister = false;
  bool _isPaymentTarget = false;
  bool _requiresReference = false;
  bool _isActive = true;
  String? _parentId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final method = widget.method;
    if (method == null) return;

    _nameController.text = method.name;
    _parentId = method.parentId;
    _currencyController.text = method.currencyCode ?? '';
    _affectsCashRegister = method.affectsCashRegister;
    _isPaymentTarget = method.isPaymentTarget;
    _requiresReference = method.requiresReference;
    _isActive = method.isActive;
  }

  @override
  void dispose() {
    _currencyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parents = PaymentMethodTreeService.parentCandidates(
      widget.methods,
      excludedId: widget.method?.id,
    );

    return AlertDialog(
      title: AppText(
        widget.method == null
            ? l10n.createPaymentMethodTitle
            : l10n.editPaymentMethodTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInput(label: l10n.nameField, controller: _nameController),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                decoration: InputDecoration(labelText: l10n.paymentParentField),
                initialValue: _parentId,
                isExpanded: true,
                items: [
                  DropdownMenuItem<String?>(
                    child: Text(
                      l10n.paymentRootOption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final parent in parents)
                    DropdownMenuItem<String?>(
                      value: parent.id,
                      child: Text(
                        PaymentMethodTreeService.pathFor(
                          widget.methods,
                          parent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _parentId = value),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: AppText(l10n.paymentFinalOptionField),
                subtitle: AppText(
                  _isPaymentTarget
                      ? l10n.modulePaymentMethods
                      : l10n.paymentNavigationNode,
                  variant: AppTextVariant.label,
                ),
                value: _isPaymentTarget,
                onChanged: (value) {
                  setState(() => _isPaymentTarget = value ?? false);
                },
              ),
              if (_isPaymentTarget) ...[
                AppInput(
                  label: l10n.currencyCodeField,
                  controller: _currencyController,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: AppText(l10n.cashAffectsRegister),
                  value: _affectsCashRegister,
                  onChanged: (value) {
                    setState(() => _affectsCashRegister = value ?? false);
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: AppText(l10n.requiresReference),
                  value: _requiresReference,
                  onChanged: (value) {
                    setState(() => _requiresReference = value ?? false);
                  },
                ),
              ],
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
    final currencyCode = _currencyController.text.trim().toUpperCase();

    if (name.isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }
    final parent = _findMethod(_parentId);
    final groupName = _resolveGroupName(name, parent);

    Navigator.of(context).pop(
      PaymentMethod(
        id: widget.method?.id ?? const Uuid().v4(),
        name: name,
        parentId: _parentId,
        groupName: groupName,
        currencyCode: !_isPaymentTarget || currencyCode.isEmpty
            ? null
            : currencyCode,
        displayOrder: widget.method?.displayOrder ?? 0,
        isPaymentTarget: _isPaymentTarget,
        affectsCashRegister: _isPaymentTarget && _affectsCashRegister,
        requiresReference: _isPaymentTarget && _requiresReference,
        isActive: _isActive,
      ),
    );
  }

  String _resolveGroupName(String name, PaymentMethod? parent) {
    if (parent == null) return name;
    var current = parent;
    while (current.parentId != null) {
      final next = _findMethod(current.parentId);
      if (next == null) break;
      current = next;
    }
    return current.name;
  }

  PaymentMethod? _findMethod(String? id) {
    if (id == null) return null;
    for (final method in widget.methods) {
      if (method.id == id) return method;
    }
    return null;
  }
}
