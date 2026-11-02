import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/app_input.dart';

void main() {
  testWidgets('required marker and inline validation are visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppInput(
            label: 'Nombre',
            requiredField: true,
            errorText: 'Campo obligatorio',
          ),
        ),
      ),
    );
    expect(find.text('Nombre *', findRichText: true), findsOneWidget);
    expect(find.text('Campo obligatorio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
