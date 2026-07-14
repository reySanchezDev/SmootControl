import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_group.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/presentation/widgets/create_product_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('shows the full category path for nested categories', (
    tester,
  ) async {
    const categories = [
      ProductCategory(
        id: 'category-1',
        name: 'CAFE CALIENTE',
        sortOrder: 1,
        isActive: true,
      ),
      ProductCategory(
        id: 'category-2',
        name: 'CAPUCCINO',
        parentId: 'category-1',
        sortOrder: 1,
        isActive: true,
      ),
      ProductCategory(
        id: 'category-3',
        name: '8 OZ',
        parentId: 'category-2',
        sortOrder: 1,
        isActive: true,
      ),
    ];

    await _pumpDialog(tester, categories: categories);

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(_dropdownFinder());
    await tester.pumpAndSettle();

    expect(find.text('CAFE CALIENTE / CAPUCCINO / 8 OZ'), findsOneWidget);
  });

  testWidgets('edits product keeping the same system id', (tester) async {
    Product? savedProduct;
    const category = ProductCategory(
      id: 'category-1',
      name: 'Cafe caliente',
      sortOrder: 1,
      isActive: true,
    );
    const product = Product(
      id: 'product-1',
      categoryId: 'category-1',
      name: 'Espresso',
      priceInCents: 3500,
      costInCents: 1200,
      isActive: true,
      isAvailableInPos: false,
    );

    await _pumpDialog(
      tester,
      categories: const [category],
      product: product,
      onSaved: (product) => savedProduct = product,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Edit product'), findsOneWidget);
    expect(find.text('Product ID'), findsNothing);
    expect(find.text('Available in POS'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Espresso doble');
    await tester.enterText(find.byType(TextField).at(1), '45');
    await tester.enterText(find.byType(TextField).at(2), '15');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedProduct?.id, 'product-1');
    expect(savedProduct?.name, 'Espresso doble');
    expect(savedProduct?.priceInCents, 4500);
    expect(savedProduct?.costInCents, 1500);
    expect(savedProduct?.isAvailableInPos, false);
  });

  testWidgets('edits product modifier groups without technical fields', (
    tester,
  ) async {
    Product? savedProduct;
    const category = ProductCategory(
      id: 'category-1',
      name: 'Comidas',
      sortOrder: 1,
      isActive: true,
    );
    const product = Product(
      id: 'product-1',
      categoryId: 'category-1',
      name: 'Carne asada',
      priceInCents: 12000,
      costInCents: 6000,
      isActive: true,
      modifierGroupIds: ['modifier-bastimento'],
    );
    const modifierGroups = [
      ModifierGroup(id: 'modifier-bastimento', name: 'Bastimento'),
      ModifierGroup(id: 'modifier-guarnicion', name: 'Guarnicion'),
    ];

    await _pumpDialog(
      tester,
      categories: const [category],
      modifierGroups: modifierGroups,
      product: product,
      onSaved: (product) => savedProduct = product,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier groups'), findsOneWidget);
    expect(find.text('Product ID'), findsNothing);
    expect(find.text('Bastimento'), findsOneWidget);
    expect(find.text('Guarnicion'), findsOneWidget);

    await tester.ensureVisible(find.text('Guarnicion'));
    await tester.tap(find.text('Guarnicion'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedProduct?.modifierGroupIds, [
      'modifier-bastimento',
      'modifier-guarnicion',
    ]);
  });

  testWidgets('allows raw material with zero sale price', (tester) async {
    Product? savedProduct;
    const category = ProductCategory(
      id: 'category-1',
      name: 'Materia prima',
      sortOrder: 1,
      isActive: true,
    );

    await _pumpDialog(
      tester,
      categories: const [category],
      onSaved: (product) => savedProduct = product,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Azucar');
    await tester.tap(_dropdownFinder());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Materia prima').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.enterText(find.byType(TextField).at(2), '12');
    await tester.tap(find.text('Raw material'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedProduct?.name, 'Azucar');
    expect(savedProduct?.priceInCents, 0);
    expect(savedProduct?.isRawMaterial, isTrue);
    expect(savedProduct?.isAvailableInPos, isFalse);
  });

  testWidgets('allows raw material with empty sale price', (tester) async {
    Product? savedProduct;
    const category = ProductCategory(
      id: 'category-1',
      name: 'Materia prima',
      sortOrder: 1,
      isActive: true,
    );

    await _pumpDialog(
      tester,
      categories: const [category],
      onSaved: (product) => savedProduct = product,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Harina');
    await tester.tap(_dropdownFinder());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Materia prima').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '16');
    await tester.tap(find.text('Raw material'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedProduct?.name, 'Harina');
    expect(savedProduct?.priceInCents, 0);
    expect(savedProduct?.isRawMaterial, isTrue);
  });

  testWidgets('rejects sellable product with zero sale price', (tester) async {
    Product? savedProduct;
    const category = ProductCategory(
      id: 'category-1',
      name: 'Bebidas',
      sortOrder: 1,
      isActive: true,
    );

    await _pumpDialog(
      tester,
      categories: const [category],
      onSaved: (product) => savedProduct = product,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Pepsi');
    await tester.tap(_dropdownFinder());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bebidas').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.enterText(find.byType(TextField).at(2), '10');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedProduct, isNull);
    expect(
      find.text('Sellable products require a sale price greater than zero.'),
      findsOneWidget,
    );
  });
}

Finder _dropdownFinder() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString().startsWith('DropdownButtonForm'),
  );
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required List<ProductCategory> categories,
  List<ModifierGroup> modifierGroups = const [],
  Product? product,
  ValueChanged<Product>? onSaved,
}) async {
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
                builder: (_) => CreateProductDialog(
                  categories: categories,
                  modifierGroups: modifierGroups,
                  product: product,
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
