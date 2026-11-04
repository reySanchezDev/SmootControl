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

    expect(saved, [367500]);
    expect(find.text('Guardado'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Guardar'), findsNothing);

    await tester.tap(find.byType(TextField));
    await tester.tap(find.text('Otra celda'));
    await tester.pumpAndSettle();
    expect(saved, [367500]);
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

    expect(saved[date.toIso8601String()], 367500);
    expect(saved.containsKey(nextDate.toIso8601String()), isFalse);
    expect(tester.widget<TextField>(fields.at(1)).focusNode!.hasFocus, isTrue);

    await tester.enterText(fields.at(1), '36.80');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(saved[nextDate.toIso8601String()], 368000);
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

    expect(amounts, [371500]);
    expect(find.text('Guardado'), findsOneWidget);
  });
  testWidgets('Tab stays in daily rates even with an earlier sidebar target', (
    tester,
  ) async {
    final focusNodes = [FocusNode(), FocusNode(), FocusNode()];
    addTearDown(() {
      for (final node in focusNodes) {
        node.dispose();
      }
    });
    final persisted = <int>[];
    Future<AppResult<ExchangeRate>> save(DateTime day, int cents) async {
      persisted.add(cents);
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
          body: Row(
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Marcadas menú'),
              ),
              Expanded(
                child: Column(
                  children: [
                    for (var day = 0; day < 3; day++)
                      ExchangeRateTile(
                        date: DateTime(2026, 11, day + 1),
                        currencyCode: 'USD',
                        onSaved: save,
                        focusNode: focusNodes[day],
                        previousFocusNode: day == 0
                            ? null
                            : focusNodes[day - 1],
                        nextFocusNode: day == 2 ? null : focusNodes[day + 1],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final fields = find.byType(TextField);
    await tester.tap(fields.first);
    await tester.enterText(fields.first, '36.71');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(focusNodes[1].hasFocus, isTrue);
    expect(persisted, [3671]);

    await tester.enterText(fields.at(1), '36.72');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(focusNodes[2].hasFocus, isTrue);
    expect(persisted, [367100, 367200]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(focusNodes[1].hasFocus, isTrue);
  });

  testWidgets('Enter focuses the next daily rate, not sidebar', (
    tester,
  ) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(() {
      first.dispose();
      second.dispose();
    });
    final saved = <int>[];
    Future<AppResult<ExchangeRate>> save(DateTime day, int cents) async {
      saved.add(cents);
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
          body: Row(
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Marcadas menú'),
              ),
              Expanded(
                child: Column(
                  children: [
                    ExchangeRateTile(
                      currencyCode: 'USD',
                      date: date,
                      onSaved: save,
                      focusNode: first,
                      nextFocusNode: second,
                    ),
                    ExchangeRateTile(
                      currencyCode: 'USD',
                      date: DateTime(2026, 11, 5),
                      onSaved: save,
                      focusNode: second,
                      previousFocusNode: first,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '36.75');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(second.hasFocus, isTrue);
    expect(saved, [367500]);
  });

  testWidgets('keyboard navigation reaches rows beyond the viewport', (
    tester,
  ) async {
    final focusNodes = List.generate(30, (_) => FocusNode());
    addTearDown(() {
      for (final node in focusNodes) {
        node.dispose();
      }
    });

    Future<AppResult<ExchangeRate>> save(DateTime day, int cents) async {
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
          body: Row(
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Marcadas menú'),
              ),
              Expanded(
                child: SizedBox(
                  height: 180,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var day = 0; day < focusNodes.length; day++)
                          ExchangeRateTile(
                            date: DateTime(2026, 11, day + 1),
                            currencyCode: 'USD',
                            onSaved: save,
                            focusNode: focusNodes[day],
                            previousFocusNode: day == 0
                                ? null
                                : focusNodes[day - 1],
                            nextFocusNode: day == focusNodes.length - 1
                                ? null
                                : focusNodes[day + 1],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField).first);
    for (var index = 1; index < focusNodes.length; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pumpAndSettle();

    expect(focusNodes.last.hasFocus, isTrue);
    expect(focusNodes[0].hasFocus, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(focusNodes[focusNodes.length - 2].hasFocus, isTrue);
    expect(focusNodes.last.hasFocus, isFalse);
  });
}
