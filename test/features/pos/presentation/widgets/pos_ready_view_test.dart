import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_ready_view.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

void main() {
  setUp(() {
    CurrentOperatorService.currentSession = null;
    serviceLocator.registerLazySingleton<CurrentOperatorService>(
      CurrentOperatorService.new,
    );
  });

  tearDown(serviceLocator.reset);

  testWidgets('renders more options without inline payment inputs', (
    tester,
  ) async {
    await _pumpReadyView(tester, state: _state('cash'));

    expect(find.text('More options'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Received'), findsNothing);
    expect(find.widgetWithText(TextField, 'Payment reference'), findsNothing);
    expect(find.text('Checkout'), findsNothing);
  });

  testWidgets('renders POS on mobile without exposing unavailable products', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _responsiveState);

    expect(tester.takeException(), isNull);
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('Menu oculto'), findsNothing);
  });

  testWidgets('renders active empty categories in the POS category band', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _responsiveState);

    expect(tester.takeException(), isNull);
    expect(find.text('Cafe caliente'), findsOneWidget);
    expect(find.text('Almuerzos'), findsOneWidget);
    expect(find.text('Postres'), findsOneWidget);
  });

  testWidgets('shows compact total band under ticket lines', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _state('cash'));

    expect(find.text(r'C$ 10.00'), findsAtLeastNWidgets(2));
  });

  testWidgets('navigates nested payment methods by touch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _nestedPaymentState);

    expect(find.text('Transferencias'), findsOneWidget);
    expect(find.text('BANPRO'), findsNothing);

    await tester.tap(find.text('Transferencias'));
    await tester.pumpAndSettle();

    expect(find.text('BANPRO'), findsOneWidget);
    expect(find.text('Cuenta 7888889'), findsNothing);

    await tester.tap(find.text('BANPRO'));
    await tester.pumpAndSettle();

    expect(find.text('Cuenta 7888889'), findsOneWidget);
  });

  testWidgets('allows exiting POS with pending table products', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _state('cash'));

    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot be exited'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks split flow when only one product unit exists', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _state('cash'));

    await tester.tap(find.text('Split accounts'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'You can split an account only when the table has more than one '
        'product.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('asks confirmation before clearing the selected table', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _state('cash'));

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Clear order'), findsOneWidget);
    expect(
      find.text(
        'All products will be removed from the selected table. This action '
        'cannot be undone.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders POS on desktop without layout exceptions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _responsiveState);

    expect(tester.takeException(), isNull);
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('Cafe caliente'), findsOneWidget);
  });

  testWidgets('renders POS on tablet without layout exceptions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _responsiveState);

    expect(tester.takeException(), isNull);
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('Menu oculto'), findsNothing);
  });
}

const _cashMethod = PaymentMethod(
  id: 'cash',
  name: 'Cash',
  affectsCashRegister: true,
  requiresReference: false,
  isActive: true,
);

const _transferMethod = PaymentMethod(
  id: 'transfer',
  name: 'Transfer',
  affectsCashRegister: false,
  requiresReference: true,
  isActive: true,
);

const _transferRoot = PaymentMethod(
  id: 'transfer-root',
  name: 'Transferencias',
  groupName: 'Transferencias',
  affectsCashRegister: false,
  requiresReference: false,
  isPaymentTarget: false,
  isActive: true,
);

const _banpro = PaymentMethod(
  id: 'banpro',
  name: 'BANPRO',
  parentId: 'transfer-root',
  groupName: 'Transferencias',
  affectsCashRegister: false,
  requiresReference: false,
  isPaymentTarget: false,
  isActive: true,
);

const _banproAccount = PaymentMethod(
  id: 'banpro-account',
  name: 'Cuenta 7888889',
  parentId: 'banpro',
  groupName: 'Transferencias',
  currencyCode: 'NIO',
  affectsCashRegister: false,
  requiresReference: true,
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

const _hiddenProduct = Product(
  id: 'product-2',
  categoryId: 'category-1',
  name: 'Menu oculto',
  priceInCents: 18000,
  costInCents: 9000,
  isActive: true,
  isAvailableInPos: false,
);

const _category = ProductCategory(
  id: 'category-1',
  name: 'Cafe caliente',
  sortOrder: 1,
  isActive: true,
);

const _table = RestaurantTable(
  id: 'table-1',
  name: 'Mesa 1',
  status: RestaurantTableStatus.available,
  isActive: true,
);

const _emptyCategory = ProductCategory(
  id: 'category-2',
  name: 'Almuerzos',
  sortOrder: 2,
  isActive: true,
);

const _thirdEmptyCategory = ProductCategory(
  id: 'category-3',
  name: 'Postres',
  sortOrder: 3,
  isActive: true,
);

PosReady _state(String selectedMethodId) {
  return PosReady(
    products: const [_product],
    tables: const [_table],
    paymentMethods: const [_cashMethod, _transferMethod],
    cartLines: const [PosCartLine(product: _product, quantity: 1)],
    selectedPaymentMethodId: selectedMethodId,
    selectedTableId: _table.id,
  );
}

const _responsiveState = PosReady(
  categories: [_category, _emptyCategory, _thirdEmptyCategory],
  products: [_product, _hiddenProduct],
  tables: [_table],
  paymentMethods: [_cashMethod],
  selectedCategoryId: 'category-1',
  selectedPaymentMethodId: 'cash',
  selectedTableId: 'table-1',
);

const _nestedPaymentState = PosReady(
  products: [_product],
  tables: [_table],
  paymentMethods: [_transferRoot, _banpro, _banproAccount],
  cartLines: [PosCartLine(product: _product, quantity: 1)],
  selectedTableId: 'table-1',
);

Future<void Function(PosReady)> _pumpReadyView(
  WidgetTester tester, {
  required PosReady state,
}) async {
  var currentState = state;
  void Function(PosReady)? updateState;

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StatefulBuilder(
        builder: (context, setState) {
          updateState = (nextState) {
            setState(() {
              currentState = nextState;
            });
          };

          return Scaffold(body: PosReadyView(state: currentState));
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return updateState!;
}
