import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/reports/domain/entities/payroll_payment_receipt.dart';
import 'package:smoo_control/features/reports/presentation/pages/payroll_payments_report_page.dart';

void main() {
  final receipt = PayrollPaymentReceipt(
    id: 'payment-1',
    employeeId: 'employee-1',
    employeeName: 'Ana López',
    employeeCode: 'E001',
    positionName: 'Cajera',
    periodStart: DateTime(2026, 11),
    periodEnd: DateTime(2026, 11, 15),
    periodLabel: 'Primera quincena',
    baseSalaryInCents: 100000,
    overtimeInCents: 0,
    consumptionInCents: 0,
    rawMaterialConsumptionInCents: 0,
    advanceDeductionInCents: 0,
    netPayInCents: 100000,
    paymentAmountInCents: 60000,
    paidAmountAfterInCents: 60000,
    balanceAfterInCents: 40000,
    advanceBalanceAfterInCents: 0,
    consumptions: const [],
    rawMaterialConsumptions: const [],
    overtimeEntries: const [],
    advances: const [],
    paidAt: DateTime(2026, 11, 3),
  );

  Future<void> setDesktop(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1366, 768);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
  }

  Widget page({
    required bool canReverse,
    required ValueChanged<PayrollPaymentReceipt> onDetails,
    required ValueChanged<PayrollPaymentReceipt> onPdf,
    required ValueChanged<PayrollPaymentReceipt> onReverse,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PayrollReceiptsCollection(
          receipts: [receipt],
          canReverse: canReverse,
          onDetails: onDetails,
          onPdf: onPdf,
          onReverse: onReverse,
        ),
      ),
    );
  }

  testWidgets('report mode has detail and PDF but never a reverse command', (
    tester,
  ) async {
    await setDesktop(tester);
    var opened = 0;
    var exported = 0;
    var reversed = 0;

    await tester.pumpWidget(
      page(
        canReverse: false,
        onDetails: (_) => opened++,
        onPdf: (_) => exported++,
        onReverse: (_) => reversed++,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eliminar pago'), findsNothing);
    await tester.tap(find.text('Ana López').last);
    await tester.pumpAndSettle();
    expect(find.text('Ver detalle'), findsOneWidget);
    expect(find.text('PDF esquela'), findsOneWidget);

    await tester.tap(find.text('Ver detalle'));
    await tester.pump();
    expect(opened, 1);

    await tester.tap(find.text('PDF esquela'));
    await tester.pump();
    expect(exported, 1);
    expect(reversed, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff mode reverses only through the provided callback', (
    tester,
  ) async {
    await setDesktop(tester);
    final reversed = <String>[];

    await tester.pumpWidget(
      page(
        canReverse: true,
        onDetails: (_) {},
        onPdf: (_) {},
        onReverse: (item) => reversed.add(item.id),
      ),
    );
    await tester.pumpAndSettle();

    final reverse = find.widgetWithText(OutlinedButton, 'Eliminar pago');
    expect(tester.widget<OutlinedButton>(reverse).onPressed, isNull);

    await tester.tap(find.text('Ana López').last);
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(reverse).onPressed, isNotNull);

    await tester.tap(reverse);
    await tester.pump();
    expect(reversed, ['payment-1']);
    expect(tester.takeException(), isNull);
  });
}
