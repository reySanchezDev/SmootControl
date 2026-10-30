import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_data_table.dart';

void main() {
  testWidgets('shared catalog collection searches and sorts real data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final items = ['Zumo', 'Agua', 'Café'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackofficeCollectionView<String>(
            items: items,
            searchLabel: 'Buscar',
            searchTextFor: (item) => item,
            emptyTitle: 'Sin resultados',
            emptyMessage: 'Cambia la búsqueda',
            columns: [
              BackofficeListColumn(
                label: 'Nombre',
                width: 400,
                compare: (a, b) => a.compareTo(b),
                cell: (_, item) => Text(item),
              ),
              BackofficeListColumn(
                label: 'Acciones',
                width: 150,
                cell: (_, item) => TextButton(
                  onPressed: () {},
                  child: Text('Editar $item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Agua'), findsOneWidget);
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Zumo'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Zumo');
    await tester.pumpAndSettle();
    // Search input and rendered row contain the same word; verify the row.
    expect(
      find.descendant(
        of: find.byType(BackofficeDataTable),
        matching: find.text('Zumo'),
      ),
      findsOneWidget,
    );
    expect(find.text('Agua'), findsNothing);
    expect(find.text('1–1 de 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared catalog collection uses cards on narrow viewport', (
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackofficeCollectionView<String>(
            items: const ['Materia prima'],
            searchLabel: 'Buscar',
            searchTextFor: (item) => item,
            emptyTitle: 'Sin resultados',
            emptyMessage: 'Cambia la búsqueda',
            columns: [
              BackofficeListColumn(
                label: 'Nombre',
                width: 320,
                compare: (a, b) => a.compareTo(b),
                cell: (_, item) => Text(item),
              ),
              BackofficeListColumn(
                label: 'Acciones',
                width: 200,
                cell: (_, item) => Text(item),
              ),
            ],
            compactBuilder: (_, item) =>
                Card(child: Text(item, softWrap: true)),
          ),
        ),
      ),
    );

    expect(find.text('Materia prima'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
