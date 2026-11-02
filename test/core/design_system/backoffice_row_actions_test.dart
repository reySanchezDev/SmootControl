import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/backoffice_row_actions.dart';

void main() {
  testWidgets('UX-040 shows every named action without overflow at 390px', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    var editCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 310,
            child: BackofficeRowActions(
              actions: [
                BackofficeRowAction(
                  label: 'Editar',
                  icon: Icons.edit_outlined,
                  onPressed: () => editCount++,
                ),
                const BackofficeRowAction(
                  label: 'Inactivar',
                  icon: Icons.toggle_off_outlined,
                  onPressed: null,
                ),
                BackofficeRowAction(
                  label: 'Quitar nivel',
                  icon: Icons.remove_circle_outline,
                  onPressed: () {},
                  destructive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Inactivar'), findsOneWidget);
    expect(find.text('Quitar nivel'), findsOneWidget);
    expect(find.text('Más'), findsNothing);
    expect(find.bySubtype<TextButton>(), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Editar'));
    expect(editCount, 1);
  });

  testWidgets('UX-040 rejects generic commands without a specific name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BackofficeRowActions(
            actions: [
              BackofficeRowAction(
                label: 'Más',
                icon: Icons.more_horiz,
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isArgumentError);
  });

  testWidgets('the first action stays aligned with differing action counts', (
    tester,
  ) async {
    Widget layout({required bool addExtra}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 350,
          child: BackofficeRowActions(
            actions: [
              const BackofficeRowAction(
                label: 'Editar',
                icon: Icons.edit_outlined,
                onPressed: null,
              ),
              if (addExtra)
                const BackofficeRowAction(
                  label: 'Inactivar',
                  icon: Icons.toggle_off_outlined,
                  onPressed: null,
                ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(layout(addExtra: false));
    final oneActionX = tester.getTopLeft(find.text('Editar')).dx;
    await tester.pumpWidget(layout(addExtra: true));
    final twoActionsX = tester.getTopLeft(find.text('Editar')).dx;

    expect(twoActionsX, oneActionX);
    expect(tester.takeException(), isNull);
  });
}
