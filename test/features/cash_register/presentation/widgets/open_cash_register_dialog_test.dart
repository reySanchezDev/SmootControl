import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/presentation/widgets/open_cash_register_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    serviceLocator.registerLazySingleton<CurrentOperatorService>(
      CurrentOperatorService.new,
    );
  });

  tearDown(() async {
    await serviceLocator.reset();
  });

  testWidgets('uses the centralized local operator when opening cash', (
    tester,
  ) async {
    CashRegisterSession? savedSession;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showDialog<CashRegisterSession>(
                  context: context,
                  builder: (_) => const OpenCashRegisterDialog(),
                );

                savedSession = result;
              },
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextFormField).first);
    await tester.pumpAndSettle();
    await _enterAmount(tester, '100');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(savedSession?.cashierId, CurrentOperatorService.localUserId);
    expect(savedSession?.openingCashInCents, 10000);
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
