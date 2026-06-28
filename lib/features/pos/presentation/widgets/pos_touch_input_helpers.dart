import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/touch_numeric_keyboard_dialog.dart';
import 'package:smoo_control/core/design_system/touch_text_keyboard_dialog.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';

/// Opens a POS text input using the global touch keyboard.
Future<void> openPosTextInput({
  required BuildContext context,
  required TextEditingController controller,
  required String label,
}) async {
  final value = await showTouchTextKeyboardDialog(
    context: context,
    initialValue: controller.text,
    label: label,
    title: label,
  );
  if (value == null || !context.mounted) return;
  controller.text = value;
}

/// Opens a POS money input using the global touch numeric keyboard.
Future<void> openPosMoneyInput({
  required BuildContext context,
  required TextEditingController controller,
  required String label,
}) async {
  final value = await showTouchNumericKeyboardDialog<String>(
    context: context,
    initialValue: controller.text,
    prefixText: '${MoneyFormatter.symbol} ',
    resultBuilder: (value) => value,
    title: label,
  );
  if (value == null || !context.mounted) return;
  controller.text = value;
}
