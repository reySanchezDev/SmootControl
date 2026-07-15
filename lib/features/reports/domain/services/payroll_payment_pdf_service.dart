import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/features/reports/domain/entities/payroll_payment_receipt.dart';

const _showEmployeePositionOnReceipt = false;

/// Builds payroll payment PDFs for employees and owners.
final class PayrollPaymentPdfService {
  /// Creates the service.
  const PayrollPaymentPdfService();

  /// Builds one employee payment receipt PDF.
  Future<Uint8List> buildEmployeeReceipt(PayrollPaymentReceipt receipt) async {
    final doc = await _document();
    doc.addPage(
      pw.MultiPage(
        theme: await _theme(),
        build: (_) => [
          _title('Esquela de pago'),
          pw.Text('Empleado: ${receipt.employeeName}'),
          if (receipt.employeeCode.isNotEmpty)
            pw.Text('Codigo: ${receipt.employeeCode}'),
          if (_showEmployeePositionOnReceipt && receipt.positionName.isNotEmpty)
            pw.Text('Puesto: ${receipt.positionName}'),
          pw.Text('Periodo: ${receipt.periodLabel}'),
          pw.Text('Fecha de pago: ${_dateTime(receipt.paidAt)}'),
          pw.SizedBox(height: 14),
          _amountsTable([
            ('Salario quincenal', receipt.baseSalaryInCents),
            ('Horas extras', receipt.overtimeInCents),
            ('Consumo descontado', receipt.consumptionInCents),
            ('Abono a adelanto', receipt.advanceDeductionInCents),
            ('Neto planilla', receipt.netPayInCents),
            ('Total pagado', receipt.paymentAmountInCents),
          ]),
          pw.SizedBox(height: 14),
          _detailsSection('Consumos aplicados', _consumptionRows(receipt)),
          pw.SizedBox(height: 10),
          _detailsSection('Horas extras pagadas', _overtimeRows(receipt)),
          pw.SizedBox(height: 10),
          _detailsSection('Adelantos aplicados', _advanceRows(receipt)),
          pw.SizedBox(height: 14),
          _amountsTable([
            ('Pendiente de nomina', receipt.balanceAfterInCents),
            (
              'Saldo adelantos proxima quincena',
              receipt.advanceBalanceAfterInCents,
            ),
          ]),
          pw.SizedBox(height: 18),
          _receiptFooter(),
        ],
      ),
    );
    return doc.save();
  }

  /// Builds a formal owner payroll report for the selected receipts.
  Future<Uint8List> buildOwnerReport({
    required List<PayrollPaymentReceipt> receipts,
    required DateTime from,
    required DateTime to,
  }) async {
    final doc = await _document();
    final totals = _PayrollTotals.fromReceipts(receipts);
    doc.addPage(
      pw.MultiPage(
        theme: await _theme(),
        build: (_) => [
          _title('Reporte formal de planilla pagada'),
          pw.Text('Periodo: ${_date(from)} - ${_date(to)}'),
          pw.Text('Generado: ${_dateTime(DateTime.now())}'),
          pw.SizedBox(height: 14),
          _amountsTable([
            ('Total salarios', totals.salary),
            ('Horas extras', totals.overtime),
            ('Consumos descontados', totals.consumption),
            ('Adelantos abonados', totals.advance),
            ('Neto planilla', totals.netPay),
            ('Total pagado', totals.paid),
            ('Pendiente nomina', totals.balance),
            ('Saldo adelantos', totals.advanceBalance),
          ]),
          pw.SizedBox(height: 14),
          _receiptsTable(receipts),
        ],
      ),
    );
    return doc.save();
  }

  Future<pw.Document> _document() async => pw.Document();

  Future<pw.ThemeData> _theme() async {
    final regular = await _font('assets/fonts/roboto-regular.ttf');
    final bold = await _font('assets/fonts/roboto-bold.ttf');
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  pw.Widget _title(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Text(
        value,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _amountsTable(List<(String, int)> rows) {
    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerLeft,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: const ['Concepto', 'Monto'],
      data: [
        for (final row in rows) [row.$1, MoneyFormatter.format(row.$2)],
      ],
    );
  }

  pw.Widget _detailsSection(String title, List<List<String>> rows) {
    if (rows.isEmpty) return pw.Text('$title: Sin registros');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: const ['Fecha', 'Detalle', 'Monto', 'Saldo'],
          data: rows,
        ),
      ],
    );
  }

  pw.Widget _receiptsTable(List<PayrollPaymentReceipt> receipts) {
    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerLeft,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: const [
        'Fecha',
        'Empleado',
        'Periodo',
        'Salario',
        'Extras',
        'Consumo',
        'Adelanto',
        'Pagado',
        'Pendiente',
      ],
      data: [
        for (final receipt in receipts)
          [
            _date(receipt.paidAt),
            receipt.employeeName,
            receipt.periodLabel,
            MoneyFormatter.format(receipt.baseSalaryInCents),
            MoneyFormatter.format(receipt.overtimeInCents),
            MoneyFormatter.format(receipt.consumptionInCents),
            MoneyFormatter.format(receipt.advanceDeductionInCents),
            MoneyFormatter.format(receipt.paymentAmountInCents),
            MoneyFormatter.format(receipt.balanceAfterInCents),
          ],
      ],
    );
  }

  pw.Widget _receiptFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 0.5)),
      ),
      child: pw.Text(
        'Este documento no requiere firma del supervisor ni del empleado. '
        'Su emision confirma que el pago fue procesado y se entrega '
        'unicamente como comprobante de control interno.',
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  List<List<String>> _consumptionRows(PayrollPaymentReceipt receipt) {
    if (receipt.consumptions.isEmpty && receipt.consumptionInCents > 0) {
      return [
        [
          _date(receipt.paidAt),
          'Consumo aplicado',
          MoneyFormatter.format(receipt.consumptionInCents),
          '-',
        ],
      ];
    }
    return [
      for (final item in receipt.consumptions)
        [
          _date(item.date),
          item.receipt,
          MoneyFormatter.format(item.amountInCents),
          '-',
        ],
    ];
  }

  List<List<String>> _overtimeRows(PayrollPaymentReceipt receipt) {
    if (receipt.overtimeEntries.isEmpty && receipt.overtimeInCents > 0) {
      return [
        [
          _date(receipt.paidAt),
          'Horas extras',
          MoneyFormatter.format(receipt.overtimeInCents),
          '-',
        ],
      ];
    }
    return [
      for (final item in receipt.overtimeEntries)
        [
          _date(item.date),
          '${item.hours} h x ${MoneyFormatter.format(item.hourRateInCents)}',
          MoneyFormatter.format(item.amountInCents),
          item.note ?? '-',
        ],
    ];
  }

  List<List<String>> _advanceRows(PayrollPaymentReceipt receipt) {
    if (receipt.advances.isEmpty && receipt.advanceDeductionInCents > 0) {
      return [
        [
          _date(receipt.paidAt),
          'Adelanto aplicado',
          MoneyFormatter.format(receipt.advanceDeductionInCents),
          MoneyFormatter.format(receipt.advanceBalanceAfterInCents),
        ],
      ];
    }
    return [
      for (final item in receipt.advances)
        [
          _date(item.deliveredAt),
          MoneyFormatter.format(item.originalAmountInCents),
          MoneyFormatter.format(item.appliedAmountInCents),
          MoneyFormatter.format(item.balanceAfterInCents),
        ],
    ];
  }

  Future<pw.Font> _font(String path) async {
    final data = await rootBundle.load(path);
    return pw.Font.ttf(data);
  }

  String _date(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String _dateTime(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${_date(date)} ${two(date.hour)}:${two(date.minute)}';
  }
}

final class _PayrollTotals {
  const _PayrollTotals({
    required this.salary,
    required this.overtime,
    required this.consumption,
    required this.advance,
    required this.netPay,
    required this.paid,
    required this.balance,
    required this.advanceBalance,
  });

  factory _PayrollTotals.fromReceipts(List<PayrollPaymentReceipt> receipts) {
    int sum(int Function(PayrollPaymentReceipt) value) =>
        receipts.fold(0, (total, receipt) => total + value(receipt));
    return _PayrollTotals(
      salary: sum((receipt) => receipt.baseSalaryInCents),
      overtime: sum((receipt) => receipt.overtimeInCents),
      consumption: sum((receipt) => receipt.consumptionInCents),
      advance: sum((receipt) => receipt.advanceDeductionInCents),
      netPay: sum((receipt) => receipt.netPayInCents),
      paid: sum((receipt) => receipt.paymentAmountInCents),
      balance: sum((receipt) => receipt.balanceAfterInCents),
      advanceBalance: receipts
          .fold(
            <String, int>{},
            (map, receipt) =>
                map..[receipt.employeeId] = receipt.advanceBalanceAfterInCents,
          )
          .values
          .fold(0, (total, value) => total + value),
    );
  }

  final int salary;
  final int overtime;
  final int consumption;
  final int advance;
  final int netPay;
  final int paid;
  final int balance;
  final int advanceBalance;
}
