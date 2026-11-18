import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/packaging/domain/entities/packaging_item.dart';
import 'package:smoo_control/features/packaging/domain/entities/product_packaging_rule.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/packaging/presentation/pages/product_packaging_rules_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  const otherProductRule = ProductPackagingRule(
    id: 'rule-other',
    productId: 'product-other',
    salesTypeId: 'type-1',
    packagingItemId: 'pack-1',
    quantityPerUnit: 9,
    isActive: true,
  );
  const productRule = ProductPackagingRule(
    id: 'rule-product',
    productId: 'product-1',
    salesTypeId: 'type-1',
    packagingItemId: 'pack-1',
    quantityPerUnit: 2,
    isActive: true,
  );

  testWidgets('shows only rules belonging to the selected product', (
    tester,
  ) async {
    await tester.pumpWidget(_dialog(rules: [productRule, otherProductRule]));
    await tester.pumpAndSettle();

    expect(find.text('Para llevar · Bolsa'), findsOneWidget);
    expect(find.text('9 por unidad · Activa'), findsNothing);
    expect(find.text('2 por unidad · Activa'), findsOneWidget);
  });

  testWidgets('creates a rule without exposing technical identifiers', (
    tester,
  ) async {
    ProductPackagingRule? saved;
    await tester.pumpWidget(
      _dialog(
        saveRule: (rule) async {
          saved = rule;
          return AppSuccess(rule);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva regla'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(saved?.productId, 'product-1');
    expect(saved?.quantityPerUnit, 3);
    expect(find.text('product-1'), findsNothing);
    expect(find.text('type-1'), findsNothing);
    expect(find.text('pack-1'), findsNothing);
  });

  testWidgets('rejects a duplicate rule before saving', (tester) async {
    var saveCalls = 0;
    await tester.pumpWidget(
      _dialog(
        rules: [productRule],
        saveRule: (rule) async {
          saveCalls++;
          return AppSuccess(rule);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva regla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(
      find.text('Ya existe esta combinación para el producto.'),
      findsOneWidget,
    );
  });

  testWidgets('shows remote failure without a success dialog', (tester) async {
    await tester.pumpWidget(
      _dialog(
        saveRule: (rule) async => const AppFailureResult(
          AppFailure(code: 'remote_failure', message: 'Fallo remoto'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva regla'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar la regla'), findsOneWidget);
    expect(find.text('Registro guardado'), findsNothing);
  });
}

Widget _dialog({
  List<ProductPackagingRule> rules = const [],
  Future<AppResult<ProductPackagingRule>> Function(ProductPackagingRule rule)?
  saveRule,
}) {
  const salesTypes = [
    SalesType(
      id: 'type-1',
      code: 'to_go',
      name: 'Para llevar',
      displayOrder: 1,
      isDefault: true,
      isActive: true,
    ),
  ];
  const packagingItems = [
    PackagingItem(
      id: 'pack-1',
      name: 'Bolsa',
      costInCents: 10,
      tracksStock: true,
      isActive: true,
    ),
  ];
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ProductPackagingRulesDialog(
      product: _product,
      rulesLoader: () async => AppSuccess(rules),
      salesTypesLoader: () async => const AppSuccess(salesTypes),
      packagingItemsLoader: () async => const AppSuccess(packagingItems),
      saveRule: saveRule,
    ),
  );
}

const _product = Product(
  id: 'product-1',
  categoryId: 'category-1',
  name: 'Producto de prueba',
  priceInCents: 100,
  costInCents: 50,
  isActive: true,
);
