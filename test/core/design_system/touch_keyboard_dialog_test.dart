import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/touch_numeric_keyboard_dialog.dart';
import 'package:smoo_control/core/design_system/touch_text_keyboard_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('text touch keyboard fits on phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpLauncher(
      tester,
      onPressed: (context) => showTouchTextKeyboardDialog(
        context: context,
        initialValue: 'MESA 1',
        label: 'Nombre visible en POS',
        title: 'Renombrar mesa',
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Renombrar mesa'), findsOneWidget);
    expect(find.text('ESPACIO'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    final firstKeyRect = tester.getRect(
      find.widgetWithText(OutlinedButton, '1').first,
    );
    final lastKeyRect = tester.getRect(
      find.widgetWithText(OutlinedButton, '0').first,
    );
    expect(firstKeyRect.left, greaterThanOrEqualTo(0));
    expect(lastKeyRect.right, lessThanOrEqualTo(360));
  });

  testWidgets('numeric touch keyboard fits on phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpLauncher(
      tester,
      onPressed: (context) => showTouchNumericKeyboardDialog<int>(
        context: context,
        initialValue: '180.00',
        prefixText: r'C$',
        resultBuilder: (_) => 18000,
        title: 'Monto Cordoba',
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Monto Cordoba'), findsOneWidget);
    expect(find.text('180.00'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, ','), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '-'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '50'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '1000'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '00'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '000'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    final firstKeyRect = tester.getRect(
      find.widgetWithText(OutlinedButton, '7'),
    );
    final lastKeyRect = tester.getRect(
      find.widgetWithText(OutlinedButton, '4'),
    );
    expect(firstKeyRect.left, greaterThanOrEqualTo(0));
    expect(lastKeyRect.right, lessThanOrEqualTo(360));
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required Future<Object?> Function(BuildContext context) onPressed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onPressed(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}
