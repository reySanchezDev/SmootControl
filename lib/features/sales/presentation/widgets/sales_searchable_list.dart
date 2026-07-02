import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_searchable_list_section.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/presentation/widgets/sale_tile.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Searchable list of sales for the selected date.
class SalesSearchableList extends StatelessWidget {
  /// Creates the sales searchable list.
  const SalesSearchableList({
    required this.onOpenDetails,
    required this.onPreviewPdf,
    required this.onVoid,
    required this.sales,
    super.key,
  });

  /// Opens the full detail for a sale.
  final void Function(BuildContext context, Sale sale) onOpenDetails;

  /// Opens the PDF preview for a sale.
  final Future<void> Function(BuildContext context, Sale sale) onPreviewPdf;

  /// Starts the void flow for a sale.
  final Future<void> Function(BuildContext context, Sale sale) onVoid;

  /// Sales loaded for the selected date.
  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppSearchableListSection<Sale>(
      emptyMessage: l10n.emptySearchMessage,
      emptyTitle: l10n.emptySearchTitle,
      items: sales,
      searchLabel: l10n.searchField,
      searchTextForItem: (sale) => [
        sale.invoiceNumber,
        sale.paymentReference ?? '',
        MoneyFormatter.format(sale.totalInCents),
        _saleStatusLabel(l10n, sale.status),
      ].join(' '),
      itemBuilder: (context, sale) => SaleTile(
        sale: sale,
        statusLabel: _saleStatusLabel(l10n, sale.status),
        onOpenDetails: () => onOpenDetails(context, sale),
        onPreviewPdf: () => onPreviewPdf(context, sale),
        onVoid: sale.status == SaleStatus.completed
            ? () => onVoid(context, sale)
            : null,
      ),
    );
  }

  String _saleStatusLabel(AppLocalizations l10n, SaleStatus status) {
    return switch (status) {
      SaleStatus.completed => l10n.saleStatusCompleted,
      SaleStatus.voided => l10n.saleStatusVoided,
    };
  }
}
