import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Shows the standard catalog inactivation confirmation dialog.
Future<bool> confirmDeactivateCatalogItem(
  BuildContext context, {
  required String name,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppConfirmationDialog(
    context,
    title: l10n.deactivateCatalogItemTitle,
    message: l10n.deactivateCatalogItemMessage(name),
    confirmLabel: l10n.deactivateAction,
    cancelLabel: l10n.cancelAction,
    destructive: true,
  );
}
