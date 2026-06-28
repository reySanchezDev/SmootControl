import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';

/// Generates a basic non-fiscal PDF receipt for a sale.
final class SaleInvoicePdfService {
  /// Creates a sale invoice PDF service.
  const SaleInvoicePdfService();

  /// Builds PDF bytes for a sale.
  Future<Uint8List> buildPdf({
    required Sale sale,
    required List<SaleItem> items,
    required BusinessSettings settings,
    required String paymentMethodName,
  }) async {
    final document = pw.Document();
    final regularFont = await _loadFont('assets/fonts/roboto-regular.ttf');
    final boldFont = await _loadFont('assets/fonts/roboto-bold.ttf');
    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );
    final subtotal = MoneyFormatter.format(sale.subtotalInCents);
    final total = MoneyFormatter.format(sale.totalInCents);

    document.addPage(
      pw.Page(
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (settings.showCompanyInfoOnReceipts) ...[
                pw.Text(
                  settings.businessName.isEmpty
                      ? 'SmooControl'
                      : settings.businessName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (_hasText(settings.legalName)) pw.Text(settings.legalName!),
                if (_hasText(settings.taxNumber))
                  pw.Text('RUC: ${settings.taxNumber}'),
                if (_hasText(settings.phone)) pw.Text(settings.phone!),
                if (_hasText(settings.address)) pw.Text(settings.address!),
                pw.SizedBox(height: 16),
              ],
              pw.Text(
                'Comprobante no fiscal',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Factura: ${sale.invoiceNumber}'),
              pw.Text('Fecha: ${_formatDate(sale.createdAt)}'),
              pw.Text('Metodo de pago: $paymentMethodName'),
              if (_hasText(sale.paymentReference))
                pw.Text('Referencia: ${sale.paymentReference}'),
              pw.SizedBox(height: 16),
              _buildItemsTable(items),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: $subtotal'),
                    pw.Text(
                      'Total: $total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return document.save();
  }

  pw.Widget _buildItemsTable(List<SaleItem> items) {
    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerLeft,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: const ['Producto', 'Cant.', 'Precio', 'Total'],
      data: [
        for (final item in items)
          [
            _productDescription(item),
            item.quantity.toString(),
            MoneyFormatter.format(item.unitPriceInCents),
            MoneyFormatter.format(item.totalInCents),
          ],
      ],
    );
  }

  String _productDescription(SaleItem item) {
    final options = item.selectedOptionsLabel;
    if (options == null || options.isEmpty) return item.productName;

    return '${item.productName}\n$options';
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  Future<pw.Font> _loadFont(String path) async {
    final fontData = await rootBundle.load(path);
    return pw.Font.ttf(fontData);
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}
