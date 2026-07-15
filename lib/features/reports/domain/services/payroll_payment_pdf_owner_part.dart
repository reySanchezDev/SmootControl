part of 'payroll_payment_pdf_service.dart';

extension _PayrollPaymentOwnerPdf on PayrollPaymentPdfService {
  List<pw.Widget> _receiptCards(List<PayrollPaymentReceipt> receipts) {
    if (receipts.isEmpty) return [pw.Text('Sin pagos en el periodo.')];
    return [
      pw.Text(
        'Detalle por empleado',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      for (final receipt in receipts) ...[
        _receiptCard(receipt),
        pw.SizedBox(height: 8),
      ],
    ];
  }

  pw.Widget _receiptCard(PayrollPaymentReceipt receipt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5, color: PdfColors.grey700),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  receipt.employeeName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Text(
                MoneyFormatter.format(receipt.paymentAmountInCents),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${receipt.periodLabel} | Pago: ${_date(receipt.paidAt)}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 6),
          _pairedAmounts([
            ('Salario', receipt.baseSalaryInCents),
            ('Horas extras', receipt.overtimeInCents),
            ('Consumo', receipt.consumptionInCents),
            ('Adelanto', receipt.advanceDeductionInCents),
            ('Neto planilla', receipt.netPayInCents),
            ('Pendiente', receipt.balanceAfterInCents),
          ]),
        ],
      ),
    );
  }

  pw.Widget _pairedAmounts(List<(String, int)> rows) {
    final tableRows = <pw.TableRow>[];
    for (var index = 0; index < rows.length; index += 2) {
      final left = rows[index];
      final right = index + 1 < rows.length ? rows[index + 1] : null;
      tableRows.add(
        pw.TableRow(
          children: [
            _amountLabel(left.$1),
            _amountValue(left.$2),
            _amountLabel(right?.$1 ?? ''),
            _amountValue(right?.$2),
          ],
        ),
      );
    }
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(),
      },
      children: tableRows,
    );
  }

  pw.Widget _amountLabel(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  pw.Widget _amountValue(int? cents) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text(
        cents == null ? '' : MoneyFormatter.format(cents),
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }
}
