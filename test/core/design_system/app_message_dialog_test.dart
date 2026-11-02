import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';

void main() {
  testWidgets('confirmation returns false on cancel and true on accept', (
    tester,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                answer = await showAppConfirmationDialog(
                  context,
                  title: 'Confirmar acción',
                  message: '¿Continuar?',
                  confirmLabel: 'Confirmar',
                  cancelLabel: 'Cancelar',
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar acción'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });
}
