import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/backoffice_collection_view.dart';
import 'package:smoo_control/core/design_system/backoffice_selection_toolbar.dart';

void main() {
  Widget collection({
    required List<_Record> items,
    required ValueChanged<_Record> onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BackofficeCollectionView<_Record>(
          items: items,
          rowKey: (record) => record.id,
          rowLabel: (record) => record.label,
          searchLabel: 'Buscar',
          searchTextFor: (record) => record.label,
          emptyTitle: 'Sin registros',
          emptyMessage: 'No se encontraron datos.',
          selectionActions: [
            BackofficeSelectionAction<_Record>(
              label: 'Eliminar',
              icon: Icons.delete_outline,
              destructive: true,
              enabledWhen: (record) => !record.locked,
              onPressed: onDelete,
            ),
          ],
          columns: [
            BackofficeListColumn<_Record>(
              label: 'Registro',
              width: 340,
              compare: (a, b) => a.label.compareTo(b.label),
              cell: (_, record) => Text(record.label),
            ),
            BackofficeListColumn<_Record>(
              label: 'Estado',
              width: 180,
              cell: (_, record) => Text(
                record.locked ? 'Aplicado a planilla' : 'Pendiente',
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('locked records cannot invoke destructive commands', (
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

    final deleted = <String>[];
    await tester.pumpWidget(
      collection(
        items: const [
          _Record('1', 'Consumo pendiente', locked: false),
          _Record('2', 'Consumo aplicado', locked: true),
        ],
        onDelete: (record) => deleted.add(record.id),
      ),
    );

    final delete = find.widgetWithText(OutlinedButton, 'Eliminar');
    expect(tester.widget<OutlinedButton>(delete).onPressed, isNull);

    await tester.tap(find.text('Consumo aplicado'));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(delete).onPressed, isNull);

    await tester.tap(find.text('Consumo pendiente'));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(delete).onPressed, isNotNull);
    await tester.tap(delete);
    expect(deleted, ['1']);
  });

  testWidgets('reloaded data cannot leave a stale destructive selection', (
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

    final deleted = <String>[];
    var records = const [_Record('1', 'Registro anterior', locked: false)];
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return collection(
            items: records,
            onDelete: (record) => deleted.add(record.id),
          );
        },
      ),
    );

    await tester.tap(find.text('Registro anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionado: Registro anterior'), findsOneWidget);

    update(
      () => records = const [_Record('2', 'Registro nuevo', locked: false)],
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Eliminar'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text('Seleccioná un registro para habilitar las acciones.'),
      findsOneWidget,
    );
    expect(deleted, isEmpty);
  });

  testWidgets('selection contract requires a key and no duplicate Actions', (
    tester,
  ) async {
    final columns = [
      BackofficeListColumn<String>(
        label: 'Registro',
        width: 160,
        cell: (_, record) => Text(record),
      ),
    ];
    final actions = [
      BackofficeSelectionAction<String>(
        label: 'Editar',
        icon: Icons.edit_outlined,
        onPressed: (_) {},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackofficeCollectionView<String>(
            items: const [],
            rowKey: (record) => record,
            columns: [
              ...columns,
              BackofficeListColumn<String>(
                label: 'Acciones',
                width: 120,
                cell: (_, record) => Text(record),
              ),
            ],
            searchTextFor: (item) => item,
            searchLabel: 'Buscar',
            emptyMessage: 'Sin datos',
            emptyTitle: 'Sin datos',
            selectionActions: actions,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });
}

class _Record {
  const _Record(this.id, this.label, {required this.locked});

  final String id;
  final String label;
  final bool locked;
}
