import 'package:flutter/material.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Shows a touch-friendly informational modal with a single OK action.
Future<void> showAppMessageDialog({
  required BuildContext context,
  required String message,
  String? title,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      return AlertDialog(
        title: title == null ? null : Text(title),
        content: Text(message),
        actions: [
          SizedBox(
            width: 120,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.okAction),
            ),
          ),
        ],
      );
    },
  );
}
