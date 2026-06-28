import 'package:flutter/material.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Shows a touch-friendly confirmation modal for risky actions.
Future<bool> showAppConfirmationDialog({
  required BuildContext context,
  required String message,
  required String title,
  String? confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      final colorScheme = Theme.of(dialogContext).colorScheme;

      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          SizedBox(
            width: 128,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancelAction),
            ),
          ),
          SizedBox(
            width: 128,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel ?? l10n.confirmAction),
            ),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
