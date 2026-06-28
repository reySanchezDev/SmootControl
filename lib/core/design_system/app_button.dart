import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';

/// Standard command button for the application.
class AppButton extends StatelessWidget {
  /// Creates a primary or secondary action button.
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    super.key,
  });

  /// Button label.
  final String label;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether to render the button as primary.
  final bool primary;

  /// Action executed when the button is pressed.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AppText(
              label,
              maxLines: 1,
              variant: AppTextVariant.label,
            ),
          ),
        ),
      ],
    );

    if (primary) {
      return FilledButton(onPressed: onPressed, child: child);
    }

    return OutlinedButton(onPressed: onPressed, child: child);
  }
}
