import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Transaction list item with user-facing sale actions.
class SaleTile extends StatelessWidget {
  /// Creates a sale tile.
  const SaleTile({
    required this.onPreviewPdf,
    required this.sale,
    required this.statusLabel,
    this.onVoid,
    super.key,
  });

  /// Opens the invoice PDF preview.
  final Future<void> Function() onPreviewPdf;

  /// Voids the sale when available.
  final Future<void> Function()? onVoid;

  /// Sale shown in the transaction list.
  final Sale sale;

  /// Localized sale status.
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      subtitle: AppText(statusLabel, variant: AppTextVariant.label),
      title: AppText(sale.invoiceNumber),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            MoneyFormatter.format(sale.totalInCents),
            variant: AppTextVariant.label,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {
              unawaited(onPreviewPdf());
            },
            tooltip: l10n.previewPdfAction,
          ),
          IconButton(
            icon: const Icon(Icons.block_outlined),
            onPressed: onVoid == null
                ? null
                : () {
                    unawaited(onVoid!());
                  },
            tooltip: l10n.voidSaleAction,
          ),
        ],
      ),
    );
  }
}
