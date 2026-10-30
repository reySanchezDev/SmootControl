import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_button.dart';

/// Shared action for creating an item in Backoffice catalog pages.
class BackofficeNewAction extends StatelessWidget {
  /// Creates the standardized primary action for an administrative page.
  const BackofficeNewAction({
    required this.onPressed,
    this.label = 'Nuevo',
    super.key,
  });

  /// Create handler; disabled when null.
  final VoidCallback? onPressed;

  /// Contextual label, short by default.
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      icon: Icons.add_rounded,
      onPressed: onPressed,
    );
  }
}
