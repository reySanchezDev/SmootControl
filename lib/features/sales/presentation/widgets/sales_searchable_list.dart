import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smoo_control/core/design_system/app_searchable_list_section.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_workspace.dart';
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

    if (BackofficeWorkspaceScope.contains(context)) {
      return BackofficeCollectionView<Sale>(
        items: sales,
        searchLabel: 'Buscar factura, referencia, importe o estado',
        searchTextFor: (sale) => [
          sale.invoiceNumber,
          sale.paymentReference ?? '',
          sale.salesTypeName ?? '',
          MoneyFormatter.format(sale.totalInCents),
          _saleStatusLabel(l10n, sale.status),
        ].join(' '),
        emptyTitle: l10n.emptySearchTitle,
        emptyMessage: l10n.emptySearchMessage,
        compactBuilder: (context, sale) => SaleTile(
          sale: sale,
          statusLabel: _saleStatusLabel(l10n, sale.status),
          onOpenDetails: () => onOpenDetails(context, sale),
          onPreviewPdf: () => onPreviewPdf(context, sale),
          onVoid: sale.status == SaleStatus.completed
              ? () => onVoid(context, sale)
              : null,
        ),
        columns: [
          BackofficeListColumn(
            label: 'Factura',
            width: 205,
            compare: (a, b) => a.invoiceNumber.compareTo(b.invoiceNumber),
            cell: (_, sale) => Text(sale.invoiceNumber, softWrap: true),
          ),
          BackofficeListColumn(
            label: 'Fecha',
            width: 180,
            alignment: Alignment.center,
            compare: (a, b) => a.createdAt.compareTo(b.createdAt),
            cell: (_, sale) => Text(
              DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt.toLocal()),
            ),
          ),
          BackofficeListColumn(
            label: 'Referencia',
            width: 230,
            compare: (a, b) => (a.paymentReference ?? '')
                .compareTo(b.paymentReference ?? ''),
            cell: (_, sale) => Text(sale.paymentReference ?? '—'),
          ),
          BackofficeListColumn(
            label: 'Total',
            width: 155,
            alignment: Alignment.centerRight,
            compare: (a, b) => a.totalInCents.compareTo(b.totalInCents),
            cell: (_, sale) => Text(
              MoneyFormatter.format(sale.totalInCents),
            ),
          ),
          BackofficeListColumn(
            label: 'Estado',
            width: 135,
            alignment: Alignment.center,
            compare: (a, b) => a.status.index.compareTo(b.status.index),
            cell: (_, sale) => Text(_saleStatusLabel(l10n, sale.status)),
          ),
          BackofficeListColumn(
            label: 'Acciones',
            width: 390,
            alignment: Alignment.center,
            cell: (_, sale) => Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => onOpenDetails(context, sale),
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('Detalle'),
                ),
                TextButton.icon(
                  onPressed: () => unawaited(onPreviewPdf(context, sale)),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                  label: Text(l10n.previewPdfAction),
                ),
                if (sale.status == SaleStatus.completed)
                  TextButton.icon(
                    onPressed: () => unawaited(onVoid(context, sale)),
                    icon: const Icon(Icons.block_outlined, size: 17),
                    label: Text(l10n.voidSaleAction),
                  ),
              ],
            ),
          ),
        ],
      );
    }

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
