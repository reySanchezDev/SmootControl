import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/cash_closing_report.dart';

/// Builds a formal cash closing PDF.
final class CashClosingPdfService {
  /// Creates a cash closing PDF service.
  const CashClosingPdfService();

  /// Builds the report document.
  Future<Uint8List> buildPdf(CashClosingReport report) async {
    final document = pw.Document();
    final regularFont = await _loadFont('assets/fonts/roboto-regular.ttf');
    final boldFont = await _loadFont('assets/fonts/roboto-bold.ttf');
    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    document.addPage(
      pw.MultiPage(
        theme: theme,
        build: (context) => [
          pw.Text(
            'Reporte formal de cierre de caja',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Periodo: ${_formatDate(report.from)} - '
            '${_formatDate(report.to)}',
          ),
          pw.Text('Generado: ${_formatDateTime(report.generatedAt)}'),
          pw.SizedBox(height: 14),
          _summaryTable(report),
          pw.SizedBox(height: 14),
          _sessionsTable(report),
          for (final session in report.sessions) ...[
            if (session.cashExpenses.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _expenseTable(session),
            ],
          ],
          pw.SizedBox(height: 18),
          pw.Text(
            'Documento de control interno generado desde SmooControl. '
            'Los montos de diferencia se calculan comparando el efectivo '
            'esperado contra el conteo fisico declarado al cierre.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _summaryTable(CashClosingReport report) {
    final physicalCash = report.hasPendingPhysicalCount
        ? 'Hay cajas sin conteo'
        : MoneyFormatter.format(report.physicalCashInCents);
    final difference = report.hasPendingPhysicalCount
        ? 'Pendiente de cierre'
        : MoneyFormatter.format(report.differenceInCents);

    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerLeft,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: const ['Concepto', 'Monto'],
      data: [
        ['Efectivo inicial', MoneyFormatter.format(report.openingCashInCents)],
        ['Ventas en efectivo', MoneyFormatter.format(report.cashSalesInCents)],
        [
          'Gastos pagados de caja',
          MoneyFormatter.format(report.cashExpensesInCents),
        ],
        [
          'Efectivo esperado',
          MoneyFormatter.format(report.expectedCashInCents),
        ],
        ['Conteo fisico', physicalCash],
        ['Diferencia', difference],
        [
          'Ventas por transferencia',
          MoneyFormatter.format(report.transferSalesInCents),
        ],
        ['Otras ventas', MoneyFormatter.format(report.otherSalesInCents)],
        [
          'Total ventas global',
          MoneyFormatter.format(report.totalSalesInCents),
        ],
      ],
    );
  }

  pw.Widget _sessionsTable(CashClosingReport report) {
    String physicalCash(CashClosingSessionReport session) {
      return session.hasPhysicalCount
          ? MoneyFormatter.format(session.physicalCashInCents)
          : 'Pendiente';
    }

    String difference(CashClosingSessionReport session) {
      return session.hasPhysicalCount
          ? MoneyFormatter.format(session.differenceInCents)
          : 'Pendiente';
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detalle por caja',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: const [
            'Fecha',
            'Cajero',
            'Efectivo',
            'Gastos',
            'Esperado',
            'Conteo',
            'Diferencia',
          ],
          data: [
            for (final session in report.sessions)
              [
                _formatDate(session.businessDate),
                session.cashierName,
                MoneyFormatter.format(session.cashSalesInCents),
                MoneyFormatter.format(session.cashExpensesInCents),
                MoneyFormatter.format(session.expectedCashInCents),
                physicalCash(session),
                difference(session),
              ],
          ],
        ),
      ],
    );
  }

  pw.Widget _expenseTable(CashClosingSessionReport session) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Gastos de caja - ${_formatDate(session.businessDate)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: const ['Hora', 'Categoria', 'Descripcion', 'Monto'],
          data: [
            for (final expense in session.cashExpenses)
              [
                _formatTime(expense.spentAt),
                expense.categoryName,
                expense.description,
                MoneyFormatter.format(expense.amountInCents),
              ],
          ],
        ),
      ],
    );
  }

  Future<pw.Font> _loadFont(String path) async {
    final fontData = await rootBundle.load(path);
    return pw.Font.ttf(fontData);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${_formatTime(date)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
