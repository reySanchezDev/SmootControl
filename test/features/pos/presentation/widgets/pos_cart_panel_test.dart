import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_cart_panel.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'hides payment reference when selected method does not require it',
    (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        state: const PosReady(
          products: [_product],
          paymentMethods: [_cashMethod],
          cartLines: [PosCartLine(product: _product, quantity: 1)],
          selectedPaymentMethodId: 'cash',
        ),
      );

      expect(find.text('Payment reference'), findsNothing);
    },
  );

  testWidgets('shows payment reference when selected method requires it', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      state: const PosReady(
        products: [_product],
        paymentMethods: [_transferMethod],
        cartLines: [PosCartLine(product: _product, quantity: 1)],
        selectedPaymentMethodId: 'transfer',
      ),
    );

    expect(find.text('Payment reference'), findsOneWidget);
  });

  testWidgets('shows split account payment controls', (tester) async {
    await _pumpPanel(
      tester,
      state: const PosReady(
        products: [_product],
        paymentMethods: [_cashMethod, _transferMethod],
        cartLines: [PosCartLine(product: _product, quantity: 2)],
        splitAccounts: [
          AccountSplitDraft(
            id: 'account-1',
            tableId: 'table-1',
            name: 'Ana',
            itemIds: ['product-1-0'],
            paymentMethodId: 'cash',
          ),
          AccountSplitDraft(
            id: 'account-2',
            tableId: 'table-1',
            name: 'Luis',
            itemIds: ['product-1-1'],
            paymentMethodId: 'transfer',
          ),
        ],
      ),
    );

    expect(find.text('Payment by account'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Luis'), findsOneWidget);
    expect(find.text('Payment reference'), findsOneWidget);
  });
}

const _cashMethod = PaymentMethod(
  id: 'cash',
  name: 'Cash',
  affectsCashRegister: true,
  requiresReference: false,
  isActive: true,
);

const _product = Product(
  id: 'product-1',
  categoryId: 'category-1',
  name: 'Cafe',
  priceInCents: 1000,
  costInCents: 500,
  isActive: true,
);

const _transferMethod = PaymentMethod(
  id: 'transfer',
  name: 'Transfer',
  affectsCashRegister: false,
  requiresReference: true,
  isActive: true,
);

Future<void> _pumpPanel(
  WidgetTester tester, {
  required PosReady state,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          height: 900,
          child: PosCartPanel(
            referenceController: TextEditingController(),
            state: state,
          ),
        ),
      ),
    ),
  );
}
