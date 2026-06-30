import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';
import 'package:smoo_control/core/design_system/app_input.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/responsive_touch_dialog_frame.dart';
import 'package:smoo_control/core/design_system/touch_numeric_keyboard_dialog.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Dialog used to open the daily cash register.
class OpenCashRegisterDialog extends StatefulWidget {
  /// Creates the open cash register dialog.
  const OpenCashRegisterDialog({super.key});

  @override
  State<OpenCashRegisterDialog> createState() => _OpenCashRegisterDialogState();
}

class _OpenCashRegisterDialogState extends State<OpenCashRegisterDialog> {
  final _openingCashController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _openingCashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ResponsiveTouchDialogFrame(
      maxWidth: 420,
      title: AppText(
        l10n.openCashRegisterTitle,
        variant: AppTextVariant.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInput(
            label: l10n.openingCashField,
            controller: _openingCashController,
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
        AppButton(label: l10n.openAction, onPressed: _submit),
      ],
    );
  }

  Future<void> _openNumericKeyboard() async {
    final l10n = AppLocalizations.of(context);
    final value = await showTouchNumericKeyboardDialog<String>(
      context: context,
      initialValue: _openingCashController.text,
      prefixText: '${MoneyFormatter.symbol} ',
      resultBuilder: (value) => value,
      title: l10n.openingCashField,
    );
    if (value == null || !mounted) return;
    setState(() {
      _error = null;
      _openingCashController.text = value;
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final openingCash = MoneyFormatter.parseToCents(
      _openingCashController.text,
    );

    if (openingCash == null) {
      setState(() => _error = l10n.numericFieldError);
      return;
    }

    Navigator.of(context).pop(
      CashRegisterSession(
        id: const Uuid().v4(),
        cashierId: serviceLocator<CurrentOperatorService>().userId,
        businessDate: DateTime.now(),
        openingCashInCents: openingCash,
        status: CashRegisterStatus.open,
      ),
    );
  }
}
