import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/reports/domain/entities/payroll_payment_receipt.dart';
import 'package:smoo_control/features/reports/domain/services/payroll_payment_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PayrollPaymentPdfService builds owner payroll report', () async {
    final from = DateTime(2026, 7);
    final receipt = PayrollPaymentReceipt(
      id: 'receipt-1',
      employeeId: 'employee-1',
      employeeName: 'Scarleth',
      employeeCode: '5',
      positionName: 'Caja',
      periodStart: from,
      periodEnd: DateTime(2026, 7, 15),
      periodLabel: 'Primera quincena de Julio 2026',
      baseSalaryInCents: 405000,
      overtimeInCents: 56950,
      consumptionInCents: 0,
      advanceDeductionInCents: 87250,
      netPayInCents: 374750,
      paymentAmountInCents: 374750,
      paidAmountAfterInCents: 374750,
      balanceAfterInCents: 0,
      advanceBalanceAfterInCents: 0,
      consumptions: const [],
      overtimeEntries: [
        PayrollReceiptOvertime(
          date: from,
          hours: 8.5,
          hourRateInCents: 6700,
          amountInCents: 56950,
        ),
      ],
      advances: const [],
      paidAt: DateTime(2026, 7, 15, 14, 21),
    );

    final bytes = await const PayrollPaymentPdfService().buildOwnerReport(
      receipts: [receipt],
      from: from,
      to: DateTime(2026, 7, 15),
    );

    expect(bytes, isNotEmpty);
  });
}
