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

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      obscureText: obscureText,
      onTap: onTap,
      readOnly: readOnly,
    );
  }
}
