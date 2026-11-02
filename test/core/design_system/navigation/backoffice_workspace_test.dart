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

  testWidgets('Inicio can close and reopen without a pinned tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackofficeWorkspace(
          items: destinations,
          pageBuilder: (_, item) => Center(child: Text('Página ${item.id}')),
        ),
      ),
    );
    expect(find.byTooltip('Cerrar Inicio'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccioná un módulo'), findsOneWidget);
    await tester.tap(find.text('Inicio').first);
    await tester.pumpAndSettle();
    expect(find.text('Página home'), findsOneWidget);
  });

  testWidgets('compact workspace navigates from responsive drawer', (
    tester,
  ) async {
    // Flutter tests use a logical viewport derived from physical pixels / DPR.
    // Fix both explicitly so this test actually exercises the 390 px layout.
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: BackofficeWorkspace(
          items: destinations,
          pageBuilder: (_, item) => Center(child: Text('Página ${item.id}')),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(BackofficeWorkspace)).width,
      390,
    );
    expect(find.byTooltip('Abrir menú'), findsOneWidget);
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    final drawerProducts = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Productos'),
    );
    expect(drawerProducts, findsOneWidget);
    await tester.tap(drawerProducts);
    await tester.pumpAndSettle();
    expect(find.text('Página products'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
