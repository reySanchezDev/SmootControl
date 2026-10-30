import 'package:flutter/material.dart';

/// Standard text input field.
class AppInput extends StatelessWidget {
  /// Creates a design-system input.
  const AppInput({
    required this.label,
    this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.onTap,
    this.obscureText = false,
    this.readOnly = false,
    this.requiredField = false,
    this.errorText,
    this.textInputAction,
    this.onFieldSubmitted,
    super.key,
  });

  /// Field label.
  final String label;

  /// Optional controller.
  final TextEditingController? controller;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Maximum visible lines.
  final int maxLines;

  /// Change callback.
  final ValueChanged<String>? onChanged;

  /// Tap callback.
  final VoidCallback? onTap;

  /// Whether the field hides the typed value.
  final bool obscureText;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Clearly marks required fields before validation.
  final bool requiredField;

  /// Contextual validation error, when applicable.
  final String? errorText;

  /// Controls the software keyboard action.
  final TextInputAction? textInputAction;

  /// Optional explicit submit behavior; defaults to the next input.
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: requiredField ? null : label,
        label: requiredField
            ? Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              )
            : null,
        errorText: errorText,
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction ??
          (maxLines == 1 ? TextInputAction.next : TextInputAction.newline),
      onFieldSubmitted: onFieldSubmitted ??
          (maxLines == 1 ? (_) => FocusScope.of(context).nextFocus() : null),
      maxLines: maxLines,
      onChanged: onChanged,
      obscureText: obscureText,
      onTap: onTap,
      readOnly: readOnly,
    );
  }
}
