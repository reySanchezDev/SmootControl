import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/pos/presentation/widgets/product_options_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('selects product options using stepped touch flow', (
    tester,
  ) async {
    List<SelectedProductOption>? selectedOptions;
    const product = Product(
      id: 'product-1',
      categoryId: 'food',
      name: 'Carne asada',
      priceInCents: 12000,
      costInCents: 6000,
      isActive: true,
      optionGroups: [
        ProductOptionGroup(
          name: 'Base',
          options: ['Gallo pinto', 'Arroz blanco'],
        ),
        ProductOptionGroup(
          name: 'Acompanamiento',
          options: ['Tortilla', 'Tajadas'],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                selectedOptions = await showDialog<List<SelectedProductOption>>(
                  context: context,
                  builder: (_) => ProductOptionsDialog(
                    product: product,
                    optionGroups: product.optionGroups,
                  ),
                );
              },
              child: const Text('Open dialog'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Base'), findsOneWidget);
    await tester.tap(find.text('Arroz blanco'));
    await tester.pumpAndSettle();

    expect(find.text('Acompanamiento'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);

    await tester.tap(find.text('Tajadas'));
    await tester.pumpAndSettle();

    expect(selectedOptions, hasLength(2));
    expect(selectedOptions?.first.optionName, 'Arroz blanco');
    expect(selectedOptions?.last.optionName, 'Tajadas');
  });

  testWidgets('allows skipping optional product option groups', (tester) async {
    List<SelectedProductOption>? selectedOptions;
    const product = Product(
      id: 'product-1',
      categoryId: 'food',
      name: 'Carne asada',
      priceInCents: 12000,
      costInCents: 6000,
      isActive: true,
      optionGroups: [
        ProductOptionGroup(
          name: 'Base',
          options: ['Gallo pinto', 'Arroz blanco'],
        ),
        ProductOptionGroup(
          name: 'Salsa extra',
          options: ['Chimichurri', 'Picante'],
          isRequired: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                selectedOptions = await showDialog<List<SelectedProductOption>>(
                  context: context,
                  builder: (_) => ProductOptionsDialog(
                    product: product,
                    optionGroups: product.optionGroups,
                  ),
                );
              },
              child: const Text('Open dialog'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallo pinto'));
    await tester.pumpAndSettle();

    expect(find.text('Salsa extra'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(selectedOptions, hasLength(1));
    expect(selectedOptions?.single.groupName, 'Base');
    expect(selectedOptions?.single.optionName, 'Gallo pinto');
  });
}
