import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_amount_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('prefills total and validates received amount', (tester) async {
    int? received;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                received = await showDialog<int>(
                  context: context,
                  builder: (_) => const PosPaymentAmountDialog(
                    methodName: 'Cordoba',
                    totalInCents: 21000,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Amount Cordoba'), findsOneWidget);
    expect(find.text('210.00'), findsOneWidget);

    await _enterAmount(tester, '100');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('The received amount does not cover the total.'),
      findsOneWidget,
    );

    await _enterAmount(tester, '250');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(received, 25000);
  });

  testWidgets('renders numeric payment dialog on short touch surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showDialog<int>(
                  context: context,
                  builder: (_) => const PosPaymentAmountDialog(
                    methodName: 'Cordoba',
                    totalInCents: 21000,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Amount Cordoba'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });
}

Future<void> _enterAmount(WidgetTester tester, String value) async {
  await tester.tap(find.widgetWithText(OutlinedButton, 'C'));
  await tester.pumpAndSettle();
  for (final digit in value.split('')) {
    await tester.tap(find.widgetWithText(OutlinedButton, digit));
    await tester.pumpAndSettle();
  }
}
