import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/responsive_touch_dialog_frame.dart';
import 'package:smoo_control/core/design_system/touch_numeric_keyboard_dialog.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Result returned by the close cash register dialog.
final class CloseCashRegisterDraft {
  /// Creates a close cash register draft.
  const CloseCashRegisterDraft({
    required this.physicalClosingCashInCents,
  });

  /// Physical closing cash count.
  final int physicalClosingCashInCents;
}

/// Dialog used to close the daily cash register.
class CloseCashRegisterDialog extends StatefulWidget {
  /// Creates the close cash register dialog.
  const CloseCashRegisterDialog({super.key});

  @override
  State<CloseCashRegisterDialog> createState() =>
      _CloseCashRegisterDialogState();
}

class _CloseCashRegisterDialogState extends State<CloseCashRegisterDialog> {
  final _closingCashController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _closingCashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ResponsiveTouchDialogFrame(
      maxWidth: 420,
      title: AppText(
        l10n.closeCashRegisterTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInput(
            label: l10n.closingCashField,
            controller: _closingCashController,
            onTap: _openNumericKeyboard,
            readOnly: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            AppText(_error!, maxLines: 2),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: l10n.cancelAction,
          onPressed: () => Navigator.of(context).pop(),
          primary: false,
        ),
        AppButton(label: l10n.closeAction, onPressed: _submit),
      ],
    );
  }

  Future<void> _openNumericKeyboard() async {
    final l10n = AppLocalizations.of(context);
    final value = await showTouchNumericKeyboardDialog<String>(
      context: context,
      initialValue: _closingCashController.text,
      prefixText: '${MoneyFormatter.symbol} ',
      resultBuilder: (value) => value,
      title: l10n.closingCashField,
    );
    if (value == null || !mounted) return;
    setState(() {
      _closingCashController.text = value;
      _error = null;
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final closingCash = MoneyFormatter.parseToCents(
      _closingCashController.text,
    );

    if (closingCash == null) {
      setState(() => _error = l10n.numericFieldError);
      return;
    }

    Navigator.of(context).pop(
      CloseCashRegisterDraft(
        physicalClosingCashInCents: closingCash,
      ),
    );
  }
}
