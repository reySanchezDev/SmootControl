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
    var detailCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SaleTile(
            onOpenDetails: () => detailCalls++,
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
    expect(detailCalls, 0);
  });

  testWidgets('opens sale detail when the sale tile is tapped', (
    tester,
  ) async {
    var detailCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SaleTile(
            onOpenDetails: () => detailCalls++,
            onPreviewPdf: () async {},
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

    await tester.tap(find.text('SM-1'));
    await tester.pump();

    expect(detailCalls, 1);
  });
}
