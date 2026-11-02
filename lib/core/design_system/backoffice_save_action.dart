import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';

/// Consistent Save action for administrative forms only.
class BackofficeSaveAction extends StatelessWidget {
  /// Builds a reusable primary command at the upper-right of the form.
  const BackofficeSaveAction({required this.onPressed, super.key});

  /// Existing persistence/validation callback.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Guardar',
      icon: Icons.save_outlined,
      onPressed: onPressed,
    );
  }
}
