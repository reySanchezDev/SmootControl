import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/touch_text_keyboard_dialog.dart';
import 'package:smoo_control/core/theme/app_semantic_colors.dart';

/// Text field used to name a generated split account.
class SplitAccountNameInput extends StatelessWidget {
  /// Creates an account-name input with a non-destructive placeholder.
  const SplitAccountNameInput({
    required this.controller,
    required this.label,
    required this.placeholder,
    super.key,
  });

  /// Controller for the user-entered account name.
  final TextEditingController controller;

  /// Visible field label.
  final String label;

  /// Suggested name shown as hint text, never as removable input text.
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final semanticColors = context.semanticColors;

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        enabledBorder: const UnderlineInputBorder(),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(width: 2),
        ),
        floatingLabelStyle: TextStyle(
          color: semanticColors.splitPanelForeground,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: semanticColors.splitPanelHint,
          fontWeight: FontWeight.w500,
        ),
        hintText: placeholder,
        labelStyle: TextStyle(
          color: semanticColors.splitPanelForeground,
          fontWeight: FontWeight.w600,
        ),
        labelText: label,
      ),
      style: TextStyle(
        color: semanticColors.splitPanelForeground,
        fontSize: 16,
      ),
      onTap: () => _openTextKeyboard(context),
      readOnly: true,
    );
  }

  Future<void> _openTextKeyboard(BuildContext context) async {
    final value = await showTouchTextKeyboardDialog(
      context: context,
      hintText: placeholder,
      initialValue: controller.text,
      label: label,
      title: label,
    );
    if (value == null || !context.mounted) return;
    controller.text = value;
  }
}
