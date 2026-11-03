import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';

void main() {
  Widget catalog({
    required ValueChanged<String> onEdit,
    bool compact = false,
  }) => MaterialApp(
    home: Scaffold(
      body: BackofficeCollectionView<String>(
        items: const ['BAC', 'Córdoba', 'Dólar'],
        searchLabel: 'Buscar método de pago',
        searchTextFor: (item) => item,
        emptyTitle: 'Sin registros',
        emptyMessage: 'No se encontraron registros',
        rowKey: (item) => item,
        rowLabel: (item) => item,
        onCreate: () {},
        selectionActions: [
          BackofficeSelectionAction(
            label: 'Editar',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          BackofficeSelectionAction(
            label: 'Quitar nivel',
            icon: Icons.remove_circle_outline,
            enabledWhen: (item) => item != 'BAC',
            onPressed: (_) {},
          ),
        ],
        columns: [
          BackofficeListColumn(
            label: 'Método de pago',
            width: 350,
            compare: (a, b) => a.compareTo(b),
            cell: (_, item) => Text(item),
          ),
        ],
        compactBuilder: compact ? (_, item) => Card(child: Text(item)) : null,
      ),
    ),
  );

  testWidgets('selected row enables only allowed explicit commands', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1366, 768);
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    String? edited;
    await tester.pumpWidget(catalog(onEdit: (item) => edited = item));
    final edit = find.widgetWithText(OutlinedButton, 'Editar');
    final remove = find.widgetWithText(OutlinedButton, 'Quitar nivel');

    expect(tester.widget<OutlinedButton>(edit).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(remove).onPressed, isNull);
    expect(find.text('Nuevo'), findsOneWidget);
    await tester.tap(find.text('BAC'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionado: BAC'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(edit).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(remove).onPressed, isNull);

    await tester.tap(edit);
    expect(edited, 'BAC');
    await tester.tap(find.text('Dólar'));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(remove).onPressed, isNotNull);

    await tester.enterText(find.byType(TextFormField), 'Córdoba');
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(edit).onPressed, isNull);
    expect(
      find.text('Seleccioná un registro para habilitar las acciones.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen selects compact cards without hidden actions', (
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

    await tester.pumpWidget(catalog(onEdit: (_) {}, compact: true));
    await tester.tap(find.text('BAC'));
    await tester.pumpAndSettle();

    expect(find.text('Seleccionado: BAC'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Quitar nivel'), findsOneWidget);
    expect(find.text('Más'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('generic More actions are rejected in administrative toolbars', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackofficeSelectionToolbar<String>(
            actions: [
              BackofficeSelectionAction<String>(
                label: 'Más',
                icon: Icons.more_horiz,
                onPressed: (_) {},
              ),
            ],
            selected: null,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isArgumentError);
  });
}
