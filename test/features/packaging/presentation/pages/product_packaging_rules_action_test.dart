import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/packaging/presentation/pages/product_packaging_rules_action.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/presentation/widgets/create_product_dialog.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

const _product = Product(
  id: 'product-1',
  categoryId: 'category-1',
  name: 'Producto de prueba',
  priceInCents: 100,
  costInCents: 50,
  isActive: true,
);

void main() {
  testWidgets('shows the rule entry only with packaging permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        permissionLoader: () async => const AppSuccess(true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Empaque y consumo'), findsOneWidget);
  });

  testWidgets('hides the rule entry without packaging permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        permissionLoader: () async => const AppSuccess(false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Empaque y consumo'), findsNothing);
  });

  testWidgets('keeps the entry disabled while product changes are pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        enabled: false,
        permissionLoader: () async => const AppSuccess(true),
      ),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Empaque y consumo'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.enabled, isFalse);
  });

  testWidgets('new product form has no rule entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CreateProductDialog(
          categories: [],
          modifierGroups: [],
        ),
      ),
    );

    expect(find.text('Empaque y consumo'), findsNothing);
  });
}

Widget _host({
  required Future<AppResult<bool>> Function() permissionLoader,
  bool enabled = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ProductPackagingRulesAction(
        product: _product,
        enabled: enabled,
        permissionLoader: permissionLoader,
      ),
    ),
  );
}
