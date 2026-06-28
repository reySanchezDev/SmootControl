import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/sales/presentation/widgets/void_sale_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('requires a reason before voiding a sale', (tester) async {
    String? reason;

    await _pumpDialog(tester, onSaved: (value) => reason = value);

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Void'));
    await tester.pumpAndSettle();

    expect(find.text('Complete the required fields.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Error de captura');
    await tester.tap(find.text('Void'));
    await tester.pumpAndSettle();

    expect(reason, 'Error de captura');
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  ValueChanged<String>? onSaved,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (_) => const VoidSaleDialog(),
              );

              if (result != null) {
                onSaved?.call(result);
              }
            },
            child: const Text('Open dialog'),
          ),
        ),
      ),
    ),
  );
}
