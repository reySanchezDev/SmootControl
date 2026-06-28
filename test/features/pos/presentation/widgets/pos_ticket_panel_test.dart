import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_ticket_panel.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('asks confirmation before removing a ticket line', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: PosTicketPanel(
              lines: [PosCartLine(product: _product, quantity: 1)],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Remove product'), findsOneWidget);
    expect(
      find.text(
        '"Coffee" will be removed from the order. This action cannot be '
        'undone.',
      ),
      findsOneWidget,
    );
  });
}

const _product = Product(
  id: 'product-1',
  categoryId: 'category-1',
  name: 'Coffee',
  priceInCents: 1000,
  costInCents: 500,
  isActive: true,
);
