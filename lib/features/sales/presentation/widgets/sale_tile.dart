import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/app_tile_actions.dart';
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
    this.onOpenDetails,
    this.onVoid,
    super.key,
  });

  /// Opens the sale detail page.
  final VoidCallback? onOpenDetails;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final total = MoneyFormatter.format(sale.totalInCents);
        return ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          onTap: onOpenDetails,
          subtitle: AppText(
            compact ? '$statusLabel - $total' : statusLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            variant: AppTextVariant.label,
          ),
          title: AppText(
            sale.invoiceNumber,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: AppTileActions(
            compact: compact,
            inlineLeading: AppText(total, variant: AppTextVariant.label),
            actions: [
              AppTileAction(
                icon: Icons.picture_as_pdf_outlined,
                label: l10n.previewPdfAction,
                onPressed: () {
                  unawaited(onPreviewPdf());
                },
              ),
              AppTileAction(
                enabled: onVoid != null,
                icon: Icons.block_outlined,
                label: l10n.voidSaleAction,
                onPressed: () {
                  unawaited(onVoid!());
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
