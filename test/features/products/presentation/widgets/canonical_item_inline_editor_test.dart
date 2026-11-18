import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/products/domain/entities/canonical_item.dart';
import 'package:smoo_control/features/products/domain/entities/measurement_unit.dart';
import 'package:smoo_control/features/products/presentation/widgets/canonical_item_editor.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

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
    name: 'Articulo existente',
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
      _app(
        CanonicalItemEditor(
          item: item,
          units: const [unit],
          classifications: const [],
          onBack: () => returns++,
          onSave: (value) => saved = value,
        ),
      ),
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Editar'), findsOneWidget);
    expect(find.text('Regresar'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(saved?.id, item.id);
    await tester.tap(find.text('Regresar'));
    await tester.pump();
    expect(returns, 1);
  });

  testWidgets('new article leaves commercial code assignment to the server', (
    tester,
  ) async {
    CanonicalItem? saved;
    await tester.pumpWidget(
      _app(
        CanonicalItemEditor(
          units: const [unit],
          classifications: const [],
          onBack: () {},
          onSave: (value) => saved = value,
        ),
      ),
    );
    expect(find.byType(TextFormField), findsNWidgets(3));
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
    expect(saved?.commercialCode, isNull);
    expect(find.text('Se asigna automáticamente al guardar.'), findsOneWidget);
  });

  testWidgets('back warns before losing edited fields', (tester) async {
    var returns = 0;
    await tester.pumpWidget(
      _app(
        CanonicalItemEditor(
          item: item,
          units: const [unit],
          classifications: const [],
          onBack: () => returns++,
          onSave: (_) {},
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre *'),
      'Articulo modificado',
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

  testWidgets('service is selected once and derives its internal role', (
    tester,
  ) async {
    CanonicalItem? saved;
    await tester.pumpWidget(
      _app(
        CanonicalItemEditor(
          units: const [unit],
          classifications: const [],
          onBack: () {},
          onSave: (value) => saved = value,
        ),
      ),
    );
    final typeField = find.byType(DropdownButtonFormField<CanonicalItemType>);
    await tester.tap(typeField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Servicio').last);
    await tester.pumpAndSettle();
    expect(find.text('Función operativa'), findsNothing);
    expect(find.text('Servicio'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre *'),
      'Servicio de entrega',
    );
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Unidad base *'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unidad (und)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(saved?.type, CanonicalItemType.service);
    expect(saved?.itemClass, CanonicalItemClass.service);
    expect(saved?.tracksInventory, isFalse);
    expect(saved?.usesRecipe, isFalse);
  });

  testWidgets('editing keeps the operational identity immutable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CanonicalItemEditor(
          item: item,
          units: const [unit],
          classifications: const [],
          onBack: () {},
          onSave: (_) {},
        ),
      ),
    );
    final roleField = tester
        .widget<DropdownButtonFormField<CanonicalItemClass>>(
          find.byType(DropdownButtonFormField<CanonicalItemClass>),
        );
    expect(roleField.onChanged, isNull);
    final typeField = find.byType(DropdownButtonFormField<CanonicalItemType>);
    final typeDropdown = tester.widget<DropdownButton<CanonicalItemType>>(
      find.descendant(
        of: typeField,
        matching: find.byType(DropdownButton<CanonicalItemType>),
      ),
    );
    expect(
      typeDropdown.items!.map((entry) => entry.value),
      isNot(contains(CanonicalItemType.service)),
    );
  });
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
