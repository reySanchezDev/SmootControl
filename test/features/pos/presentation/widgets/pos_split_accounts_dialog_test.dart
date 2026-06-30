import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_accounts_dialog.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  testWidgets('moves split account items by touch', (tester) async {
    await _pumpDialog(tester);

    await tester.tap(find.byKey(const ValueKey('split-item-product-1-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-account-account-1')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('split-account-account-1')),
        matching: find.byKey(const ValueKey('split-item-product-1-0')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses placeholders for generated account names', (tester) async {
    await _pumpDialog(tester);

    final editableTexts = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();

    expect(editableTexts, hasLength(2));
    expect(editableTexts[0].controller.text, isEmpty);
    expect(editableTexts[1].controller.text, isEmpty);
    expect(find.text('Cuenta 1'), findsOneWidget);
    expect(find.text('Cuenta 2'), findsOneWidget);
  });

  testWidgets('moves multiple selected items by touch', (tester) async {
    await _pumpDialog(tester);

    await tester.tap(find.byKey(const ValueKey('split-item-product-1-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-item-product-1-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-account-account-1')));
    await tester.pumpAndSettle();

    final account = find.byKey(const ValueKey('split-account-account-1'));
    expect(
      find.descendant(
        of: account,
        matching: find.byKey(const ValueKey('split-item-product-1-0')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: account,
        matching: find.byKey(const ValueKey('split-item-product-1-1')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('moves selected item between child accounts', (tester) async {
    await _pumpDialog(tester, state: _splitState);

    await tester.tap(find.byKey(const ValueKey('split-item-product-1-1')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('split-horizontal-list')),
      const Offset(-420, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-account-account-2')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('split-account-account-2')),
        matching: find.byKey(const ValueKey('split-item-product-1-1')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('moves split account items by drag and drop', (tester) async {
    await _pumpDialog(tester);

    final item = find.byKey(const ValueKey('split-item-product-1-0'));
    final account = find.byKey(const ValueKey('split-account-account-1'));
    final gesture = await tester.startGesture(tester.getCenter(item));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(account));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: account,
        matching: find.byKey(const ValueKey('split-item-product-1-0')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('removing an extra split account returns its items', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDialog(tester, state: _splitState);

    final removeButton = find.byKey(
      const ValueKey('split-remove-account-3'),
    );
    await tester.pumpAndSettle();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(find.text('Remove account'), findsOneWidget);
    expect(
      find.text(
        'The "Cuenta 3" account will be removed and its products will return '
        'to the original order.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('split-original-panel')),
        matching: find.byKey(const ValueKey('split-item-product-1-0')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows validation as an OK dialog', (tester) async {
    await _pumpDialog(tester);

    await tester.tap(find.byKey(const ValueKey('split-confirm')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('renders split workspace on constrained touch surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDialog(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('split-original-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('split-account-account-1')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpDialog(WidgetTester tester, {PosReady state = _state}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PosSplitAccountsDialog(state: state)),
    ),
  );
}

const _product = Product(
  id: 'product-1',
  categoryId: 'category-1',
  name: 'Carne asada',
  priceInCents: 12000,
  costInCents: 6000,
  isActive: true,
);

const _table = RestaurantTable(
  id: 'table-1',
  name: 'Mesa 1',
  status: RestaurantTableStatus.available,
  isActive: true,
);

const _method = PaymentMethod(
  id: 'cash',
  name: 'Cash',
  affectsCashRegister: true,
  requiresReference: false,
  isActive: true,
);

const _state = PosReady(
  products: [_product],
  tables: [_table],
  paymentMethods: [_method],
  cartLines: [PosCartLine(product: _product, quantity: 2)],
  selectedTableId: 'table-1',
  selectedPaymentMethodId: 'cash',
);

const _splitState = PosReady(
  products: [_product],
  tables: [_table],
  paymentMethods: [_method],
  cartLines: [PosCartLine(product: _product, quantity: 2)],
  selectedTableId: 'table-1',
  selectedPaymentMethodId: 'cash',
  splitAccounts: [
    AccountSplitDraft(
      id: 'account-1',
      tableId: 'table-1',
      name: 'Cuenta 1',
      itemIds: ['product-1-1'],
    ),
    AccountSplitDraft(
      id: 'account-2',
      tableId: 'table-1',
      name: 'Cuenta 2',
      itemIds: [],
    ),
    AccountSplitDraft(
      id: 'account-3',
      tableId: 'table-1',
      name: 'Cuenta 3',
      itemIds: ['product-1-0'],
    ),
  ],
);
