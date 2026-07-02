import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/presentation/widgets/create_category_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('does not expose technical category fields', (tester) async {
    await _pumpDialog(tester);

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Category ID'), findsNothing);
    expect(find.text('Parent category ID'), findsNothing);
    expect(find.text('Sort order'), findsNothing);
    expect(find.text('Type'), findsNothing);
    expect(find.text('Place inside'), findsOneWidget);
    expect(find.text('Posicion POS'), findsOneWidget);
  });

  testWidgets('creates nested category by selecting any active parent', (
    tester,
  ) async {
    ProductCategory? savedCategory;
    final categories = [
      const ProductCategory(
        id: 'category-1',
        name: 'Bebidas',
        sortOrder: 1,
        isActive: true,
      ),
      const ProductCategory(
        id: 'subcategory-1',
        name: 'CAPUCCINO',
        parentId: 'category-1',
        sortOrder: 3,
        isActive: true,
      ),
    ];

    await _pumpDialog(
      tester,
      categories: categories,
      onSaved: (category) => savedCategory = category,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '8 OZ');
    await tester.tap(_dropdownFinder().first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CAPUCCINO').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedCategory?.name, '8 OZ');
    expect(savedCategory?.parentId, 'subcategory-1');
    expect(savedCategory?.sortOrder, 1);
  });

  testWidgets('saves the configured POS position', (tester) async {
    ProductCategory? savedCategory;

    await _pumpDialog(
      tester,
      onSaved: (category) => savedCategory = category,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Bebida');
    await tester.enterText(fields.at(1), '2');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedCategory?.name, 'Bebida');
    expect(savedCategory?.sortOrder, 2);
  });

  testWidgets('rejects invalid POS position', (tester) async {
    ProductCategory? savedCategory;

    await _pumpDialog(
      tester,
      onSaved: (category) => savedCategory = category,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Bebida');
    await tester.enterText(fields.at(1), '0');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedCategory, isNull);
    expect(find.text('Enter a valid number.'), findsOneWidget);
  });

  testWidgets('edits category keeping the same system id', (tester) async {
    ProductCategory? savedCategory;
    const category = ProductCategory(
      id: 'category-1',
      name: 'Bebidas',
      sortOrder: 2,
      isActive: true,
    );

    await _pumpDialog(
      tester,
      categories: const [category],
      category: category,
      onSaved: (category) => savedCategory = category,
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Edit category'), findsOneWidget);
    expect(find.text('Category ID'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Bebidas frias');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedCategory?.id, 'category-1');
    expect(savedCategory?.name, 'Bebidas frias');
    expect(savedCategory?.sortOrder, 2);
  });
}

Finder _dropdownFinder() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString().startsWith('DropdownButtonForm'),
  );
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  ProductCategory? category,
  List<ProductCategory> categories = const [],
  ValueChanged<ProductCategory>? onSaved,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<ProductCategory>(
                context: context,
                builder: (_) => CreateCategoryDialog(
                  categories: categories,
                  category: category,
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
