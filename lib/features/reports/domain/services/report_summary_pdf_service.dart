import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/report_summary.dart';

/// Builds a basic PDF for a report summary.
final class ReportSummaryPdfService {
  /// Creates a report summary PDF service.
  const ReportSummaryPdfService();

  /// Builds PDF bytes for the selected report summary.
  Future<Uint8List> buildPdf(ReportSummary summary) async {
    final document = pw.Document();
    final regularFont = await _loadFont('assets/fonts/roboto-regular.ttf');
    final boldFont = await _loadFont('assets/fonts/roboto-bold.ttf');
    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    document.addPage(
      pw.MultiPage(
        theme: theme,
        build: (context) => [
          pw.Text(
            'Reporte operativo',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Rango: ${_rangeLabel(summary)}'),
          pw.SizedBox(height: 16),
          _metricsTable(summary),
          pw.SizedBox(height: 16),
          _cashTable(summary),
          pw.SizedBox(height: 16),
          _productsTable('Productos mas vendidos', summary.topProducts),
          pw.SizedBox(height: 16),
          _productsTable('Productos menos vendidos', summary.lowestProducts),
          pw.SizedBox(height: 16),
          _voidsTable(summary),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _metricsTable(ReportSummary summary) {
    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerLeft,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: const ['Metrica', 'Valor'],
      data: [
        ['Ventas', MoneyFormatter.format(summary.grossSalesInCents)],
        ['Ganancia bruta', MoneyFormatter.format(summary.grossProfitInCents)],
        ['Gastos', MoneyFormatter.format(summary.expensesInCents)],
        ['Ganancia real', MoneyFormatter.format(summary.netProfitInCents)],
        [
          'Ticket promedio',
          MoneyFormatter.format(summary.averageTicketInCents),
        ],
        ['Ventas registradas', summary.salesCount.toString()],
        ['Anulaciones', summary.voidsCount.toString()],
      ],
    );
  }

  pw.Widget _cashTable(ReportSummary summary) {
    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerLeft,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: const ['Caja', 'Valor'],
      data: [
        ['Cajas registradas', summary.cashSessionsCount.toString()],
        ['Efectivo inicial', MoneyFormatter.format(summary.cashOpeningInCents)],
        ['Ventas efectivo', MoneyFormatter.format(summary.cashSalesInCents)],
        ['Gastos caja', MoneyFormatter.format(summary.cashExpensesInCents)],
        [
          'Efectivo esperado',
          MoneyFormatter.format(summary.cashExpectedInCents),
        ],
        ['Conteo fisico', MoneyFormatter.format(summary.cashPhysicalInCents)],
        ['Diferencia', MoneyFormatter.format(summary.cashDifferenceInCents)],
      ],
    );
  }

  pw.Widget _productsTable(String title, List<ProductSalesMetric> metrics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: const ['Producto', 'Unidades', 'Ventas', 'Ganancia'],
          data: [
            for (final metric in metrics.take(8))
              [
                metric.productName,
                metric.quantity.toString(),
                MoneyFormatter.format(metric.salesInCents),
                MoneyFormatter.format(metric.profitInCents),
              ],
          ],
        ),
      ],
    );
  }

  pw.Widget _voidsTable(ReportSummary summary) {
    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerLeft,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: const ['Fecha', 'Venta', 'Motivo', 'Usuario'],
      data: [
        for (final saleVoid in summary.voids)
          [
            _formatDateTime(saleVoid.voidedAt),
            saleVoid.saleId,
            saleVoid.reason,
            saleVoid.voidedBy,
          ],
      ],
    );
  }

  Future<pw.Font> _loadFont(String path) async {
    final fontData = await rootBundle.load(path);
    return pw.Font.ttf(fontData);
  }

  String _rangeLabel(ReportSummary summary) {
    final inclusiveTo = summary.to.subtract(const Duration(days: 1));
    return '${_formatDate(summary.from)} - ${_formatDate(inclusiveTo)}';
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    final time = '${twoDigits(date.hour)}:${twoDigits(date.minute)}';

    return '${_formatDate(date)} $time';
  }
}
