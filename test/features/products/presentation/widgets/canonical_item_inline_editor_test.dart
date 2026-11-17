import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_editor.dart';

void main() {
  const unit = MeasurementUnit(
    id: 'unit-one',
    code: 'und',
    name: 'Unidad',
    unitGroup: 'count',
    baseFactor: 1,
    isActive: true,
  );
  const item = CanonicalItem(
    id: 'item-one',
    code: 'ART-1',
    name: 'Artículo existente',
    type: CanonicalItemType.inventory,
    baseUnitId: 'unit-one',
    cost: 1,
    price: 2,
    canSell: true,
  );

  testWidgets('editor stays in the workspace and returns without navigation', (
    tester,
  ) async {
    var returns = 0;
    CanonicalItem? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanonicalItemEditor(
            item: item,
            units: const [unit],
            classifications: const [],
            onBack: () => returns++,
            onSave: (value) => saved = value,
          ),
        ),
      ),
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Editar artículo'), findsOneWidget);
    expect(find.text('Regresar'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(saved?.id, item.id);
    await tester.tap(find.text('Regresar'));
    await tester.pump();
    expect(returns, 1);
  });

  testWidgets('new article uses server-generated code, not manual input', (
    tester,
  ) async {
    CanonicalItem? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanonicalItemEditor(
            units: const [unit],
            classifications: const [],
            onBack: () {},
            onSave: (value) => saved = value,
          ),
        ),
      ),
    );
    expect(find.textContaining('Código'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre *'),
      'Coca-Cola',
    );
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Unidad base *'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unidad (und)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(saved?.name, 'Coca-Cola');
    expect(saved?.code, '');
  });

  testWidgets('back warns before losing edited fields', (tester) async {
    var returns = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanonicalItemEditor(
            item: item,
            units: const [unit],
            classifications: const [],
            onBack: () => returns++,
            onSave: (_) {},
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre *'),
      'Artículo modificado',
    );
    await tester.tap(find.text('Regresar'));
    await tester.pumpAndSettle();
    expect(find.text('Cambios sin guardar'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(returns, 0);
    await tester.tap(find.text('Regresar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(returns, 1);
  });
}
