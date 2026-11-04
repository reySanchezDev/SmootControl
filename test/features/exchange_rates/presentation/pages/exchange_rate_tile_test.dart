import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/exchange_rates/domain/entities/exchange_rate.dart';
import 'package:smoo_control/features/exchange_rates/presentation/pages/exchange_rates_page.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  final date = DateTime(2026, 11, 4);

  Widget harness(
    Future<AppResult<ExchangeRate>> Function(DateTime, int) save, {
    ExchangeRate? initial,
  }) {
    return MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            ExchangeRateTile(
              date: date,
              currencyCode: 'USD',
              rate: initial,
              onSaved: save,
            ),
            TextButton(onPressed: () {}, child: const Text('Otra celda')),
          ],
        ),
      ),
    );
  }

  testWidgets('leaving an edited cell auto-saves exactly once', (
    tester,
  ) async {
    final saved = <int>[];
    await tester.pumpWidget(
      harness((date, cents) async {
        saved.add(cents);
        return AppSuccess(
          ExchangeRate(
            currencyCode: 'USD',
            businessDate: date,
            rateInCents: cents,
          ),
        );
      }),
    );

    await tester.enterText(find.byType(TextField), '36.75');
    await tester.tap(find.text('Otra celda'));
    await tester.pumpAndSettle();

    expect(saved, [3675]);
    expect(find.text('Guardado'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Guardar'), findsNothing);

    await tester.tap(find.byType(TextField));
    await tester.tap(find.text('Otra celda'));
    await tester.pumpAndSettle();
    expect(saved, [3675]);
  });

  testWidgets('unchanged rate never issues a save', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      harness(
        (_, cents) async {
          calls++;
          return AppSuccess(
            ExchangeRate(
              currencyCode: 'USD',
              businessDate: date,
              rateInCents: cents,
            ),
          );
        },
        initial: ExchangeRate(
          currencyCode: 'USD',
          businessDate: date,
          rateInCents: 3650,
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.tap(find.text('Otra celda'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('server failure retains typed rate and exposes error', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness((_, _) async {
        return const AppFailureResult(
          AppFailure(code: 'network', message: 'Sin conexión'),
        );
      }),
    );

    await tester.enterText(find.byType(TextField), '36.85');
    await tester.tap(find.text('Otra celda'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, '36.85');
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Guardado'), findsNothing);
  });

  testWidgets('invalid value is not sent to the repository', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      harness((_, _) async {
        calls++;
        throw StateError('No debe llamarse');
      }),
    );

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Otra celda'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.textContaining('mayor que cero'), findsOneWidget);
  });
  testWidgets('Tab saves the first rate and focuses the next daily cell', (
    tester,
  ) async {
    final saved = <String, int>{};
    final nextDate = DateTime(2026, 11, 5);
    Future<AppResult<ExchangeRate>> save(DateTime day, int cents) async {
      saved[day.toIso8601String()] = cents;
      return AppSuccess(
        ExchangeRate(
          currencyCode: 'USD',
          businessDate: day,
          rateInCents: cents,
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              ExchangeRateTile(
                date: date,
                currencyCode: 'USD',
                onSaved: save,
              ),
              ExchangeRateTile(
                date: nextDate,
                currencyCode: 'USD',
                onSaved: save,
              ),
            ],
          ),
        ),
      ),
    );
    final fields = find.byType(TextField);
    await tester.tap(fields.first);
    await tester.enterText(fields.first, '36.75');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(saved[date.toIso8601String()], 3675);
    expect(saved.containsKey(nextDate.toIso8601String()), isFalse);
    expect(tester.widget<TextField>(fields.at(1)).focusNode!.hasFocus, isTrue);

    await tester.enterText(fields.at(1), '36.80');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(saved[nextDate.toIso8601String()], 3680);
    expect(saved.length, 2);
  });

  testWidgets('Enter commits and advances without duplicate saves', (
    tester,
  ) async {
    final amounts = <int>[];
    await tester.pumpWidget(
      harness((day, cents) async {
        amounts.add(cents);
        return AppSuccess(
          ExchangeRate(
            currencyCode: 'USD',
            businessDate: day,
            rateInCents: cents,
          ),
        );
      }),
    );

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '37.15');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(amounts, [3715]);
    expect(find.text('Guardado'), findsOneWidget);
  });

}
