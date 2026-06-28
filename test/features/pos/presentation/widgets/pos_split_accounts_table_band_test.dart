import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_ready_view.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('orders occupied tables before free tables', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _tableOrderState);

    final mesa9Left = tester.getTopLeft(find.text('Mesa 9')).dx;
    final mesa7Left = tester.getTopLeft(find.text('Mesa 7')).dx;
    final mesa1Left = tester.getTopLeft(find.text('Mesa 1')).dx;

    expect(mesa9Left, lessThan(mesa7Left));
    expect(mesa7Left, lessThan(mesa1Left));
    expect(find.text('Occupied'), findsNWidgets(2));
    expect(find.textContaining('items'), findsNothing);
  });

  testWidgets('shows split accounts next to their original table', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _splitAccountsState);

    final tableLeft = tester.getTopLeft(find.text('Mesa 1')).dx;
    final pedroLeft = tester.getTopLeft(find.text('Pedro')).dx;
    final juanLeft = tester.getTopLeft(find.text('Juan')).dx;
    final mesa2Left = tester.getTopLeft(find.text('Mesa 2')).dx;

    expect(tableLeft, lessThan(pedroLeft));
    expect(pedroLeft, lessThan(juanLeft));
    expect(juanLeft, lessThan(mesa2Left));
    expect(find.text('Cuenta'), findsNWidgets(2));
  });
}

Future<void> _pumpReadyView(
  WidgetTester tester, {
  required PosReady state,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PosReadyView(state: state)),
    ),
  );
  await tester.pumpAndSettle();
}

const _product = Product(
  id: 'product-1',
  categoryId: 'category-1',
  name: 'Cafe',
  priceInCents: 1000,
  costInCents: 500,
  isActive: true,
);

const _cashMethod = PaymentMethod(
  id: 'cash',
  name: 'Cash',
  affectsCashRegister: true,
  requiresReference: false,
  isActive: true,
);

const _table = RestaurantTable(
  id: 'table-1',
  name: 'Mesa 1',
  status: RestaurantTableStatus.available,
  isActive: true,
);

const _table2 = RestaurantTable(
  id: 'table-2',
  name: 'Mesa 2',
  status: RestaurantTableStatus.available,
  isActive: true,
);

const _table7 = RestaurantTable(
  id: 'table-7',
  name: 'Mesa 7',
  status: RestaurantTableStatus.available,
  isActive: true,
);

const _table9 = RestaurantTable(
  id: 'table-9',
  name: 'Mesa 9',
  status: RestaurantTableStatus.available,
  isActive: true,
);

const _tableOrderState = PosReady(
  products: [_product],
  tables: [_table, _table7, _table9],
  paymentMethods: [_cashMethod],
  cartLines: [PosCartLine(product: _product, quantity: 1)],
  cartLinesByTable: {
    'table-9': [PosCartLine(product: _product, quantity: 1)],
    'table-7': [PosCartLine(product: _product, quantity: 1)],
  },
  selectedPaymentMethodId: 'cash',
  selectedTableId: 'table-9',
);

const _splitAccountsState = PosReady(
  products: [_product],
  tables: [_table, _table2],
  paymentMethods: [_cashMethod],
  splitSourceLinesByTable: {
    'table-1': [PosCartLine(product: _product, quantity: 2)],
  },
  splitAccountsByTable: {
    'table-1': [
      AccountSplitDraft(
        id: 'account-1',
        tableId: 'table-1',
        name: 'Pedro',
        itemIds: ['product-1-0'],
      ),
      AccountSplitDraft(
        id: 'account-2',
        tableId: 'table-1',
        name: 'Juan',
        itemIds: ['product-1-1'],
      ),
    ],
  },
  selectedPaymentMethodId: 'cash',
  selectedTableId: 'table-1',
);
