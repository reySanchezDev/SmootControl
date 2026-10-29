import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/design_system/backoffice_data_table.dart';
import 'package:smoo_control/core/theme/backoffice_theme.dart';

void main() {
  testWidgets('Executive Ivory table renders headings and action cells',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BackofficeTheme.executiveIvory,
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: BackofficeDataTable(
              columns: const ['Producto', 'Precio', 'Acciones'],
              rows: [
                [
                  const Text('Café'),
                  const Text('C$ 50'),
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {},
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Producto'), findsOneWidget);
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('C$ 50'), findsOneWidget);
    expect(find.byTooltip('Editar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
