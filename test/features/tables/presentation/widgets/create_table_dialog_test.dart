import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/features/tables/presentation/widgets/create_table_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('edits table keeping the same system id', (tester) async {
    RestaurantTable? savedTable;
    const table = RestaurantTable(
      id: 'table-1',
      name: 'Mesa 1',
      status: RestaurantTableStatus.available,
      isActive: true,
    );

    await _pumpDialog(
      tester,
      table: table,
      onSaved: (table) => savedTable = table,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Edit table'), findsOneWidget);
    expect(find.text('Table ID'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Terraza 1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedTable?.id, 'table-1');
    expect(savedTable?.name, 'Terraza 1');
    expect(savedTable?.status, RestaurantTableStatus.available);
  });

  testWidgets('marks inactive tables as disabled', (tester) async {
    RestaurantTable? savedTable;
    const table = RestaurantTable(
      id: 'table-1',
      name: 'Mesa 1',
      status: RestaurantTableStatus.available,
      isActive: true,
    );

    await _pumpDialog(
      tester,
      table: table,
      onSaved: (table) => savedTable = table,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedTable?.isActive, isFalse);
    expect(savedTable?.status, RestaurantTableStatus.disabled);
  });

  testWidgets('reactivates disabled tables as available', (tester) async {
    RestaurantTable? savedTable;
    const table = RestaurantTable(
      id: 'table-1',
      name: 'Mesa 1',
      status: RestaurantTableStatus.disabled,
      isActive: false,
    );

    await _pumpDialog(
      tester,
      table: table,
      onSaved: (table) => savedTable = table,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedTable?.isActive, isTrue);
    expect(savedTable?.status, RestaurantTableStatus.available);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  RestaurantTable? table,
  ValueChanged<RestaurantTable>? onSaved,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<RestaurantTable>(
                context: context,
                builder: (_) => CreateTableDialog(table: table),
              );

              if (result != null) {
                onSaved?.call(result);
              }
            },
            child: const Text('Open dialog'),
          ),
        ),
      ),
    ),
  );
}
