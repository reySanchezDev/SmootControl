import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_confirmation_dialog.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Confirms clearing every line from the active POS ticket.
Future<bool> confirmClearPosTicket(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppConfirmationDialog(
    context: context,
    message: l10n.clearCartConfirmMessage,
    title: l10n.clearCartConfirmTitle,
    confirmLabel: l10n.clearCartAction,
  );
}

/// Confirms removing one line from the active POS ticket.
Future<bool> confirmRemovePosLine(
  BuildContext context, {
  required PosCartLine line,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppConfirmationDialog(
    context: context,
    message: l10n.removeCartLineConfirmMessage(line.product.name),
    title: l10n.removeCartLineConfirmTitle,
    confirmLabel: l10n.removeAction,
  );
}

/// Confirms removing a generated split account.
Future<bool> confirmRemoveSplitAccount(
  BuildContext context, {
  required String name,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppConfirmationDialog(
    context: context,
    message: l10n.removeSplitAccountConfirmMessage(name),
    title: l10n.removeSplitAccountConfirmTitle,
    confirmLabel: l10n.removeAction,
  );
}
