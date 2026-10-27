import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/navigation/backoffice_workspace.dart';

void main() {
  const destinations = <BackofficeWorkspaceItem>[
    BackofficeWorkspaceItem(
      id: 'home',
      label: 'Inicio',
      route: '/',
      icon: Icons.home_outlined,
      closable: false,
    ),
    BackofficeWorkspaceItem(
      id: 'products',
      label: 'Productos',
      route: '/products',
      icon: Icons.inventory_2_outlined,
    ),
  ];

  testWidgets('opens module tabs and keeps both pages mounted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackofficeWorkspace(
          items: destinations,
          pageBuilder: (_, item) => Center(child: Text('Página ${item.id}')),
        ),
      ),
    );

    expect(find.text('Página home'), findsOneWidget);
    await tester.tap(find.text('Productos').first);
    await tester.pumpAndSettle();
    expect(find.text('Página products'), findsOneWidget);
    expect(
      find.text('Página home', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byTooltip('Cerrar Productos'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar Productos'));
    await tester.pumpAndSettle();
    expect(find.text('Página products'), findsNothing);
    expect(find.text('Página home'), findsOneWidget);
  });

  testWidgets('veto preserves a tab when there are unsaved changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackofficeWorkspace(
          items: destinations,
          initialItemId: 'products',
          onCloseRequested: (_) async => false,
          pageBuilder: (_, item) => Center(child: Text('Página ${item.id}')),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Cerrar Productos'));
    await tester.pumpAndSettle();
    expect(find.text('Página products'), findsOneWidget);
  });
}
