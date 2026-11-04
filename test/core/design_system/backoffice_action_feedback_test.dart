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
    await tester.pump();
  }

  testWidgets('success is explicitly identified only when requested', (
    tester,
  ) async {
    await show(
      tester,
      BackofficeActionOutcome.success,
      'Tasa aplicada correctamente.',
    );
    expect(find.text('Correcto: Tasa aplicada correctamente.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('validation rejection is a warning, not a success', (
    tester,
  ) async {
    await show(
      tester,
      BackofficeActionOutcome.warning,
      'Ingresá una tasa válida.',
    );
    expect(find.text('Atención: Ingresá una tasa válida.'), findsOneWidget);
    expect(find.textContaining('Correcto:'), findsNothing);
  });

  testWidgets('server failure is explicitly identified as error', (
    tester,
  ) async {
    await show(
      tester,
      BackofficeActionOutcome.error,
      'No se completó el mes.',
    );
    expect(find.text('Error: No se completó el mes.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
