import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/backoffice_action_feedback.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    BackofficeActionOutcome outcome,
    String message,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => BackofficeActionFeedback.show(
                context,
                outcome: outcome,
                message: message,
              ),
              child: const Text('Acción'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Acción'));
    await tester.pumpAndSettle();
  }

  testWidgets('success is a modal dialog, never a snackbar', (tester) async {
    await show(
      tester,
      BackofficeActionOutcome.success,
      'Tasa aplicada correctamente.',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Operación exitosa'), findsOneWidget);
    expect(find.text('Tasa aplicada correctamente.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('validation rejection displays warning dialog', (
    tester,
  ) async {
    await show(
      tester,
      BackofficeActionOutcome.warning,
      'Ingresá una tasa válida.',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Atención'), findsOneWidget);
    expect(find.text('Ingresá una tasa válida.'), findsOneWidget);
    expect(find.text('Operación exitosa'), findsNothing);
  });

  testWidgets('remote failure displays error dialog', (tester) async {
    await show(
      tester,
      BackofficeActionOutcome.error,
      'No se completó el mes.',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
    expect(find.text('No se completó el mes.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('neutral information uses a separate dialog type', (
    tester,
  ) async {
    await show(
      tester,
      BackofficeActionOutcome.info,
      'Los registros están sincronizados.',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Información'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
