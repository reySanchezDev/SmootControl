import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/catalog/presentation/widgets/catalog_tree_list.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('starts collapsed and expands a full root category group', (
    tester,
  ) async {
    await _pumpTree(tester);

    expect(find.text('Bebidas Frias'), findsOneWidget);
    expect(find.text('Coca Cola'), findsNothing);
    expect(find.text('Fresca'), findsNothing);

    await tester.tap(find.byTooltip('Expand group').first);
    await tester.pumpAndSettle();

    expect(find.text('Coca Cola'), findsOneWidget);
    expect(find.text('Fresca'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse group').first);
    await tester.pumpAndSettle();

    expect(find.text('Bebidas Frias'), findsOneWidget);
    expect(find.text('Coca Cola'), findsNothing);
    expect(find.text('Fresca'), findsNothing);
  });

  testWidgets('keeps only one root group expanded at a time', (tester) async {
    await _pumpTree(tester);

    await tester.tap(find.byTooltip('Expand group').first);
    await tester.pumpAndSettle();

    expect(find.text('Coca Cola'), findsOneWidget);
    expect(find.text('Asados'), findsNothing);

    await tester.tap(find.byTooltip('Expand group').last);
    await tester.pumpAndSettle();

    expect(find.text('Coca Cola'), findsNothing);
    expect(find.text('Fresca'), findsNothing);
    expect(find.text('Asados'), findsOneWidget);
  });

  testWidgets('does not expose remove action on root categories', (
    tester,
  ) async {
    await _pumpTree(tester);

    await tester.tap(find.byTooltip('Expand group').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
  });
}

const _categories = [
  ProductCategory(
    id: 'root-1',
    name: 'Bebidas Frias',
    sortOrder: 1,
    isActive: true,
  ),
  ProductCategory(
    id: 'subcategory-1',
    name: 'Coca Cola',
    parentId: 'root-1',
    sortOrder: 1,
    isActive: true,
  ),
  ProductCategory(
    id: 'subcategory-2',
    name: 'Fresca',
    parentId: 'subcategory-1',
    sortOrder: 1,
    isActive: true,
  ),
  ProductCategory(
    id: 'root-2',
    name: 'Almuerzos',
    sortOrder: 2,
    isActive: true,
  ),
  ProductCategory(
    id: 'subcategory-3',
    name: 'Asados',
    parentId: 'root-2',
    sortOrder: 1,
    isActive: true,
  ),
];

Future<void> _pumpTree(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CatalogTreeList(
          categories: _categories,
          onEdit: (_) {},
          onRemove: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
