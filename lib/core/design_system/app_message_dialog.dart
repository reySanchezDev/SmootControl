import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Standardized confirmation/notice UI for all modules.
class AppMessageDialog extends StatelessWidget {
  /// Creates an accessible decision dialog.
  const AppMessageDialog({
    required this.title,
    required this.message,
    required this.acceptLabel,
    this.cancelLabel,
    this.destructive = false,
    super.key,
  });

  /// Human-readable action title.
  final String title;

  /// Explanation or consequence of the action.
  final String message;

  /// Label for the affirmative action.
  final String acceptLabel;

  /// Label for the alternative, when present.
  final String? cancelLabel;

  /// Whether the affirmative action is destructive.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(
        destructive ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
        color: destructive ? colors.error : colors.primary,
      ),
      title: AppText(title, variant: AppTextVariant.titleMedium),
      content: AppText(message),
      actions: [
        if (cancelLabel != null)
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: AppText(cancelLabel!),
          ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: AppText(acceptLabel),
        ),
      ],
    );
  }
}

/// Shows a decision; dismissing the dialog never confirms.
Future<bool> showAppConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AppMessageDialog(
      title: title,
      message: message,
      acceptLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

/// Shows an acknowledgment dialog; retains the existing public API.
Future<void> showAppMessageDialog({
  required BuildContext context,
  required String message,
  String? title,
}) async {
  final l10n = AppLocalizations.of(context);
  await showDialog<bool>(
    context: context,
    builder: (_) => AppMessageDialog(
      title: title ?? l10n.appTitle,
      message: message,
      acceptLabel: l10n.okAction,
    ),
  );
}
