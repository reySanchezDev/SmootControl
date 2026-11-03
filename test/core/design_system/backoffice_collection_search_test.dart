import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';

void main() {
  Widget records({bool showSearch = true}) => MaterialApp(
    home: Scaffold(
      body: BackofficeCollectionView<String>(
        items: const ['Café molido', 'Azúcar morena', 'Piña natural'],
        columns: [
          BackofficeListColumn<String>(
            label: 'Producto',
            width: 350,
            compare: (a, b) => a.compareTo(b),
            cell: (_, item) => Text(item),
          ),
        ],
        searchLabel: 'Buscar producto',
        searchTextFor: (item) => item,
        emptyTitle: 'Sin resultados',
        emptyMessage: 'No se encontraron productos.',
        showSearch: showSearch,
      ),
    ),
  );

  testWidgets('search ignores accents while preserving result labels', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(records());

    await tester.enterText(find.byType(TextFormField), 'cafe');
    await tester.pumpAndSettle();
    expect(find.text('Café molido'), findsOneWidget);
    expect(find.text('Azúcar morena'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'pina');
    await tester.pumpAndSettle();
    expect(find.text('Piña natural'), findsOneWidget);
    expect(find.text('Café molido'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded tables can omit duplicate search fields', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(records(showSearch: false));

    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Café molido'), findsOneWidget);
    expect(find.text('Piña natural'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
