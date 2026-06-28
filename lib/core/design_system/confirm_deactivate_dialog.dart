import 'package:flutter/material.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Shows the standard catalog inactivation confirmation dialog.
Future<bool> confirmDeactivateCatalogItem(
  BuildContext context, {
  required String name,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.deactivateCatalogItemTitle),
      content: Text(l10n.deactivateCatalogItemMessage(name)),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.deactivateAction),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
