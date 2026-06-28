import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Dialog used to capture the reason for voiding a sale.
class VoidSaleDialog extends StatefulWidget {
  /// Creates the void sale dialog.
  const VoidSaleDialog({super.key});

  @override
  State<VoidSaleDialog> createState() => _VoidSaleDialogState();
}

class _VoidSaleDialogState extends State<VoidSaleDialog> {
  final _reasonController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: AppText(
        l10n.voidSaleTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(
              controller: _reasonController,
              label: l10n.voidReasonField,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AppText(_error!, maxLines: 2),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(
          label: l10n.cancelAction,
          onPressed: () => Navigator.of(context).pop(),
          primary: false,
        ),
        AppButton(
          label: l10n.voidSaleAction,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final reason = _reasonController.text.trim();

    if (reason.isEmpty) {
      setState(() => _error = l10n.fieldRequiredError);
      return;
    }

    Navigator.of(context).pop(reason);
  }
}
