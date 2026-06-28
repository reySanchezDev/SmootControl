import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/presentation/widgets/create_product_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('creates product with reusable modifier groups in one save', (
    tester,
  ) async {
    Product? savedProduct;

    await _pumpDialog(
      tester,
      onSaved: (product) => savedProduct = product,
    );

    await _fillBaseProduct(tester);
    await _selectModifierGroup(tester, 'Bastimento');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedProduct?.name, 'Carne asada');
    expect(savedProduct?.modifierGroupIds, ['modifier-bastimento']);
    expect(savedProduct?.optionGroups, isEmpty);
  });

  testWidgets('creates product with two reusable modifier groups', (
    tester,
  ) async {
    Product? savedProduct;

    await _pumpDialog(
      tester,
      onSaved: (product) => savedProduct = product,
    );

    await _fillBaseProduct(tester);
    await _selectModifierGroup(tester, 'Bastimento');
    await _selectModifierGroup(tester, 'Guarnicion');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedProduct?.modifierGroupIds, [
      'modifier-bastimento',
      'modifier-guarnicion',
    ]);
  });

  testWidgets('allows saving product without modifier groups', (
    tester,
  ) async {
    Product? savedProduct;

    await _pumpDialog(
      tester,
      onSaved: (product) => savedProduct = product,
    );

    await _fillBaseProduct(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedProduct?.name, 'Carne asada');
    expect(savedProduct?.modifierGroupIds, isEmpty);
  });
}

Future<void> _fillBaseProduct(WidgetTester tester) async {
  await tester.tap(find.text('Open dialog'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'Carne asada');
  await tester.tap(_dropdownFinder());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Almuerzos').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(1), '180');
  await tester.enterText(find.byType(TextField).at(2), '90');
}

Future<void> _selectModifierGroup(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text(name));
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Finder _dropdownFinder() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString().startsWith('DropdownButtonForm'),
  );
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  ValueChanged<Product>? onSaved,
}) async {
  const category = ProductCategory(
    id: 'category-1',
    name: 'Almuerzos',
    sortOrder: 1,
    isActive: true,
  );
  const modifierGroups = [
    ModifierGroup(id: 'modifier-bastimento', name: 'Bastimento'),
    ModifierGroup(id: 'modifier-guarnicion', name: 'Guarnicion'),
  ];

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<Product>(
                context: context,
                builder: (_) => const CreateProductDialog(
                  categories: [category],
                  modifierGroups: modifierGroups,
                ),
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
