import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/presentation/widgets/sale_tile.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('opens receipt preview from the sale tile action', (
    tester,
  ) async {
    var previewCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SaleTile(
            onPreviewPdf: () async => previewCalls++,
            sale: Sale(
              id: 'sale-1',
              invoiceNumber: 'SM-1',
              paymentMethodId: 'cash',
              status: SaleStatus.completed,
              subtotalInCents: 8000,
              totalInCents: 8000,
              createdAt: DateTime(2026, 6, 24, 10),
            ),
            statusLabel: 'Completed',
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Preview receipt'));
    await tester.pump();

    expect(previewCalls, 1);
  });
}
