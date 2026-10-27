import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_sidebar.dart';

void main() {
  testWidgets('sidebar collapses and preserves navigation callbacks', (
    tester,
  ) async {
    var collapsed = false;
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Row(
              children: [
                BackofficeSidebar(
                  items: const [
                    BackofficeNavItem(
                      id: 'products',
                      label: 'Productos',
                      group: 'Catálogo',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ],
                  activeId: 'products',
                  collapsed: collapsed,
                  onCollapsedChanged: (value) =>
                      setState(() => collapsed = value),
                  onSelected: (value) => selected = value,
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Productos'), findsOneWidget);
    await tester.tap(find.byTooltip('Contraer menú'));
    await tester.pumpAndSettle();
    expect(collapsed, isTrue);
    expect(find.byTooltip('Expandir menú'), findsOneWidget);
    await tester.tap(find.byTooltip('Productos'));
    expect(selected, 'products');
    await tester.tap(find.byTooltip('Expandir menú'));
    await tester.pumpAndSettle();
    expect(collapsed, isFalse);
    expect(find.text('Productos'), findsOneWidget);
  });

  testWidgets(
    'sidebar supports active state, tooltips, keyboard and desktop sizes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var collapsed = true;
      String? selected;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      Widget buildPage() => MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Row(
              children: [
                BackofficeSidebar(
                  items: const [
                    BackofficeNavItem(
                      id: 'dashboard',
                      label: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                    ),
                  ],
                  activeId: 'dashboard',
                  collapsed: collapsed,
                  onCollapsedChanged: (value) =>
                      setState(() => collapsed = value),
                  onSelected: (value) => selected = value,
                ),
                Expanded(
                  child: Focus(
                    focusNode: focusNode,
                    child: const SizedBox(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(buildPage());
      expect(find.byTooltip('Dashboard'), findsOneWidget);
      final dashboardSemantics = tester.getSemantics(
        find.byTooltip('Dashboard'),
      );
      expect(
        dashboardSemantics.flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(tester.takeException(), isNull);

      final dashboardInkWell = find.descendant(
        of: find.byTooltip('Dashboard'),
        matching: find.byType(InkWell),
      );
      await tester.tap(dashboardInkWell);
      expect(selected, 'dashboard');

      selected = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(selected, 'dashboard');

      await tester.tap(find.byTooltip('Expandir menú'));
      await tester.pumpAndSettle();
      expect(collapsed, isFalse);
      expect(find.text('Dashboard'), findsOneWidget);

      final handle = find.byTooltip('Contraer menú');
      await tester.tap(handle);
      await tester.pumpAndSettle();
      expect(collapsed, isTrue);

      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
