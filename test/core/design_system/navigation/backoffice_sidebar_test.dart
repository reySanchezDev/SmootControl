import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_sidebar.dart';

void main() {
  testWidgets('sidebar collapses and preserves navigation callbacks', (tester) async {
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
}
