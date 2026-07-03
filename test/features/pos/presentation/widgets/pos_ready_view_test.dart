import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_category_band.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_ready_view.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_ticket_panel.dart';
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

  testWidgets(
    'uses abbreviated sales type labels and hides exchange on phone',
    (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpReadyView(tester, state: _mobileSalesTypeState);

      expect(tester.takeException(), isNull);
      expect(find.text('Aquí'), findsOneWidget);
      expect(find.text('GO'), findsOneWidget);
      expect(find.text('Comer aqui'), findsNothing);
      expect(find.text('Para llevar'), findsNothing);
      expect(find.byIcon(Icons.currency_exchange_outlined), findsNothing);
    },
  );

  testWidgets('keeps tablet sales type buttons next to product visibility', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1280));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _mobileSalesTypeState);

    expect(tester.takeException(), isNull);
    expect(find.text('Comer aqui'), findsOneWidget);
    expect(find.text('Para llevar'), findsOneWidget);

    final hideRect = tester.getRect(find.text('Hide'));
    final dineInRect = tester.getRect(find.text('Comer aqui'));
    expect(dineInRect.left - hideRect.right, lessThan(140));
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

  testWidgets('keeps tablet portrait catalog height content aware', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1280));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _tabletPortraitCatalogState);

    expect(tester.takeException(), isNull);
    final subcategoryRect = tester.getRect(find.text('ASADOS'));
    final rootCategoryRect = tester.getRect(find.text('Comidas'));

    expect(rootCategoryRect.top - subcategoryRect.bottom, lessThan(120));
  });

  testWidgets('shows long subcategory names fully on phone catalog tiles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(489, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _phoneLongSubcategoryState);

    expect(tester.takeException(), isNull);
    expect(find.text('COMBOS POLLO'), findsOneWidget);

    final labelRect = tester.getRect(find.text('COMBOS POLLO'));
    final categoryBandRect = tester.getRect(find.byType(PosCategoryBand));
    expect(labelRect.height, greaterThan(14));
    expect(labelRect.bottom, lessThan(categoryBandRect.top));
  });

  testWidgets('uses two catalog columns on phone surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _phoneLongSubcategoryState);

    expect(tester.takeException(), isNull);
    final firstRect = tester.getRect(find.text('ASADOS'));
    final secondRect = tester.getRect(find.text('BUFETE'));
    final thirdRect = tester.getRect(find.text('COMBOS POLLO'));

    expect((firstRect.top - secondRect.top).abs(), lessThan(8));
    expect(secondRect.left, greaterThan(firstRect.right));
    expect(thirdRect.top, greaterThan(firstRect.bottom));
  });

  testWidgets('keeps phone categories separated from catalog content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _phoneCatalogProductsState);

    expect(tester.takeException(), isNull);
    final lastVisibleProductRect = tester.getRect(find.text(r'C$ 120.00'));
    final categoryBandRect = tester.getRect(find.byType(PosCategoryBand));

    expect(categoryBandRect.top, greaterThan(lastVisibleProductRect.bottom));
  });

  testWidgets('hides phone catalog without hiding category controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _phoneCatalogProductsState);

    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Show'), findsOneWidget);
    expect(find.text('ENCHILADAS'), findsNothing);
    expect(find.text('Cafe caliente'), findsOneWidget);

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('ENCHILADAS'), findsOneWidget);
  });

  testWidgets(
    'keeps phone total band from overlapping categories when catalog is hidden',
    (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpReadyView(tester, state: _veryDenseResponsiveState);

      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final ticketRect = tester.getRect(find.byType(PosTicketPanel));
      final categoryBandRect = tester.getRect(find.byType(PosCategoryBand));

      expect(categoryBandRect.top - ticketRect.bottom, lessThan(8));
    },
  );

  testWidgets('toggles phone cart mode without exposing the ticket total', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpReadyView(tester, state: _mobileSalesTypeState);

    expect(tester.takeException(), isNull);
    expect(find.text(r'C$ 0.00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(r'C$ 0.00'), findsNothing);
    expect(find.text('Hide'), findsNothing);
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.byType(PosCategoryBand), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(r'C$ 0.00'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
  });

  test('orders phone table navigation with occupied tables first', () {
    final ordered = orderMobilePosTables(
      cartLinesByTable: const {
        'table-2': [PosCartLine(product: _product, quantity: 1)],
      },
      splitAccountsByTable: const {},
      tables: const [
        RestaurantTable(
          id: 'table-1',
          name: 'Mesa 1',
          status: RestaurantTableStatus.available,
          isActive: true,
        ),
        RestaurantTable(
          id: 'table-3',
          name: 'Mesa 3',
          status: RestaurantTableStatus.occupied,
          isActive: true,
        ),
        RestaurantTable(
          id: 'table-2',
          name: 'Mesa 2',
          status: RestaurantTableStatus.available,
          isActive: true,
        ),
      ],
    );

    expect(ordered.map((table) => table.name), ['Mesa 2', 'Mesa 3', 'Mesa 1']);
  });

  testWidgets('renders dense POS content across constrained surfaces', (
    tester,
  ) async {
    const sizes = [
      Size(393, 852),
      Size(390, 720),
      Size(600, 960),
      Size(720, 1024),
      Size(1024, 600),
      Size(1280, 800),
    ];
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in sizes) {
      await tester.binding.setSurfaceSize(size);
      await _pumpReadyView(tester, state: _denseResponsiveState);

      expect(tester.takeException(), isNull, reason: 'surface: $size');
      expect(find.text('Pollo asado familiar'), findsAtLeastNWidgets(1));
      expect(find.text('Menu oculto'), findsNothing);
    }
  });

  testWidgets('keeps POS actions reachable on phone-width touch surfaces', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await _pumpReadyView(tester, state: _veryDenseResponsiveState);

    expect(tester.takeException(), isNull);
    expect(find.text('Pollo asado familiar'), findsAtLeastNWidgets(1));
    final tablesFinder = find.text('TABLES', skipOffstage: false);
    expect(tablesFinder, findsAtLeastNWidgets(1));
    expect(find.text('Mesa 3', skipOffstage: false), findsNothing);

    final optionsFinder = find.textContaining(
      RegExp('options|opciones', caseSensitive: false),
    );

    expect(optionsFinder, findsOneWidget);
    expect(
      find.textContaining(RegExp('cash|efectivo', caseSensitive: false)),
      findsNothing,
    );

    await tester.tap(optionsFinder);
    await tester.pumpAndSettle();

    expect(find.text('Split accounts'), findsAtLeastNWidgets(1));
    expect(find.text('Clear'), findsOneWidget);
    expect(
      find.textContaining(RegExp('cash|efectivo', caseSensitive: false)),
      findsAtLeastNWidgets(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps phone table launcher visible after adding products', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    final updateState = await _pumpReadyView(tester, state: _responsiveState);
    updateState(_veryDenseResponsiveState);
    await tester.pumpAndSettle();

    expect(find.text('Cafe caliente'), findsOneWidget);
    expect(find.text('TABLES'), findsOneWidget);
    expect(find.text('Mesa 1'), findsOneWidget);
    expect(find.text('More options'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('orders compact more options by operational priority', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(() {
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });

    await _pumpReadyView(tester, state: _veryDenseResponsiveState);

    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();

    final modifiersRect = tester.getRect(
      find.text('Modificadores Disponibles'),
    );
    final expenseRect = tester.getRect(find.text('Register Expense'));
    final syncRect = tester.getRect(find.text('Sincronizar datos'));
    final transactionsRect = tester.getRect(find.text('View Transactions'));
    final clearText = tester.widget<Text>(find.text('Clear'));
    final clearContext = tester.element(find.text('Clear'));

    expect(modifiersRect.top, lessThan(expenseRect.top));
    expect(expenseRect.top, lessThan(syncRect.top));
    expect(syncRect.top, lessThan(transactionsRect.top));
    expect(
      clearText.style?.color,
      Theme.of(clearContext).colorScheme.onError,
    );
    expect(tester.takeException(), isNull);
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

const _dineInSalesType = SalesType(
  id: 'sales-type-dine-in',
  code: 'dine_in',
  name: 'Comer aqui',
  displayOrder: 1,
  isDefault: true,
  isActive: true,
);

const _toGoSalesType = SalesType(
  id: 'sales-type-to-go',
  code: 'to_go',
  name: 'Para llevar',
  displayOrder: 2,
  isDefault: false,
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

const _foodRootCategory = ProductCategory(
  id: 'food-root',
  name: 'Comidas',
  sortOrder: 1,
  isActive: true,
);

const _grilledSubcategory = ProductCategory(
  id: 'grilled-subcategory',
  name: 'ASADOS',
  parentId: 'food-root',
  sortOrder: 1,
  isActive: true,
);

const _buffetSubcategory = ProductCategory(
  id: 'buffet-subcategory',
  name: 'BUFETE',
  parentId: 'food-root',
  sortOrder: 2,
  isActive: true,
);

const _comboChickenSubcategory = ProductCategory(
  id: 'combo-chicken-subcategory',
  name: 'COMBOS POLLO',
  parentId: 'food-root',
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

const _mobileSalesTypeState = PosReady(
  categories: [_category],
  products: [_product],
  tables: [_table],
  paymentMethods: [_cashMethod],
  salesTypes: [_dineInSalesType, _toGoSalesType],
  selectedCategoryId: 'category-1',
  selectedPaymentMethodId: 'cash',
  selectedSalesTypeId: 'sales-type-dine-in',
  selectedTableId: 'table-1',
);

const _tabletPortraitCatalogState = PosReady(
  categories: [_foodRootCategory, _grilledSubcategory],
  products: [],
  tables: [
    _table,
    RestaurantTable(
      id: 'table-2',
      name: 'Mesa 2',
      status: RestaurantTableStatus.available,
      isActive: true,
    ),
    RestaurantTable(
      id: 'table-3',
      name: 'Mesa 3',
      status: RestaurantTableStatus.available,
      isActive: true,
    ),
  ],
  paymentMethods: [_cashMethod],
  selectedCategoryId: 'food-root',
  selectedPaymentMethodId: 'cash',
  selectedTableId: 'table-1',
);

const _phoneLongSubcategoryState = PosReady(
  categories: [
    _foodRootCategory,
    _grilledSubcategory,
    _buffetSubcategory,
    _comboChickenSubcategory,
  ],
  products: [],
  tables: [_table],
  paymentMethods: [_cashMethod],
  selectedCategoryId: 'food-root',
  selectedPaymentMethodId: 'cash',
  selectedTableId: 'table-1',
);

const _phoneCatalogProductsState = PosReady(
  categories: [_category, _emptyCategory, _thirdEmptyCategory],
  products: [
    Product(
      id: 'phone-product-1',
      categoryId: 'category-1',
      name: 'ENCHILADAS',
      priceInCents: 6000,
      costInCents: 3000,
      isActive: true,
    ),
    Product(
      id: 'phone-product-2',
      categoryId: 'category-1',
      name: 'MADURO + QUESO',
      priceInCents: 8000,
      costInCents: 4000,
      isActive: true,
    ),
    Product(
      id: 'phone-product-3',
      categoryId: 'category-1',
      name: 'ORDEN TACOS',
      priceInCents: 12000,
      costInCents: 6000,
      isActive: true,
    ),
    Product(
      id: 'phone-product-4',
      categoryId: 'category-1',
      name: 'TAJADAS CON QUESO',
      priceInCents: 6000,
      costInCents: 3000,
      isActive: true,
    ),
  ],
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

const _denseResponsiveState = PosReady(
  categories: [
    _category,
    _emptyCategory,
    _thirdEmptyCategory,
    ProductCategory(
      id: 'category-4',
      name: 'Bebidas naturales largas',
      sortOrder: 4,
      isActive: true,
    ),
    ProductCategory(
      id: 'category-5',
      name: 'Especiales de cocina',
      sortOrder: 5,
      isActive: true,
    ),
  ],
  products: [
    Product(
      id: 'dense-product-1',
      categoryId: 'category-1',
      name: 'Pollo asado familiar',
      priceInCents: 36000,
      costInCents: 18000,
      isActive: true,
    ),
    Product(
      id: 'dense-product-2',
      categoryId: 'category-1',
      name: 'Carne asada con guarniciones especiales',
      priceInCents: 42000,
      costInCents: 21000,
      isActive: true,
    ),
    _hiddenProduct,
  ],
  tables: [
    _table,
    RestaurantTable(
      id: 'table-2',
      name: 'Mesa 2',
      status: RestaurantTableStatus.available,
      isActive: true,
    ),
    RestaurantTable(
      id: 'table-3',
      name: 'Mesa terraza principal',
      status: RestaurantTableStatus.available,
      isActive: true,
    ),
  ],
  paymentMethods: [
    _cashMethod,
    _transferRoot,
    _banpro,
    _banproAccount,
  ],
  cartLines: [
    PosCartLine(
      product: Product(
        id: 'dense-product-1',
        categoryId: 'category-1',
        name: 'Pollo asado familiar',
        priceInCents: 36000,
        costInCents: 18000,
        isActive: true,
      ),
      quantity: 2,
    ),
    PosCartLine(
      product: Product(
        id: 'dense-product-2',
        categoryId: 'category-1',
        name: 'Carne asada con guarniciones especiales',
        priceInCents: 42000,
        costInCents: 21000,
        isActive: true,
      ),
      quantity: 1,
    ),
  ],
  cartLinesByTable: {
    'table-1': [
      PosCartLine(
        product: Product(
          id: 'dense-product-1',
          categoryId: 'category-1',
          name: 'Pollo asado familiar',
          priceInCents: 36000,
          costInCents: 18000,
          isActive: true,
        ),
        quantity: 2,
      ),
    ],
  },
  selectedCategoryId: 'category-1',
  selectedPaymentMethodId: 'cash',
  selectedTableId: 'table-1',
);

const _veryDenseResponsiveState = PosReady(
  categories: [
    _category,
    _emptyCategory,
    _thirdEmptyCategory,
    ProductCategory(
      id: 'category-4',
      name: 'Bebidas naturales largas',
      sortOrder: 4,
      isActive: true,
    ),
    ProductCategory(
      id: 'category-5',
      name: 'Especiales de cocina',
      sortOrder: 5,
      isActive: true,
    ),
  ],
  products: [
    Product(
      id: 'dense-product-1',
      categoryId: 'category-1',
      name: 'Pollo asado familiar',
      priceInCents: 36000,
      costInCents: 18000,
      isActive: true,
    ),
    Product(
      id: 'dense-product-2',
      categoryId: 'category-1',
      name: 'Carne asada con guarniciones especiales',
      priceInCents: 42000,
      costInCents: 21000,
      isActive: true,
    ),
    Product(
      id: 'dense-product-3',
      categoryId: 'category-1',
      name: 'Refresco natural grande',
      priceInCents: 12000,
      costInCents: 6000,
      isActive: true,
    ),
    _hiddenProduct,
  ],
  tables: [
    _table,
    RestaurantTable(
      id: 'table-2',
      name: 'Mesa 2',
      status: RestaurantTableStatus.available,
      isActive: true,
    ),
    RestaurantTable(
      id: 'table-3',
      name: 'Mesa 3',
      status: RestaurantTableStatus.available,
      isActive: true,
    ),
    RestaurantTable(
      id: 'table-4',
      name: 'Mesa 4',
      status: RestaurantTableStatus.available,
      isActive: true,
    ),
    RestaurantTable(
      id: 'table-5',
      name: 'Mesa 5',
      status: RestaurantTableStatus.available,
      isActive: true,
    ),
    RestaurantTable(
      id: 'table-6',
      name: 'Mesa terraza principal',
      status: RestaurantTableStatus.available,
      isActive: true,
    ),
  ],
  paymentMethods: [
    _cashMethod,
    _transferRoot,
    _banpro,
    _banproAccount,
  ],
  cartLines: [
    PosCartLine(
      product: Product(
        id: 'dense-product-1',
        categoryId: 'category-1',
        name: 'Pollo asado familiar',
        priceInCents: 36000,
        costInCents: 18000,
        isActive: true,
      ),
      quantity: 2,
    ),
    PosCartLine(
      product: Product(
        id: 'dense-product-2',
        categoryId: 'category-1',
        name: 'Carne asada con guarniciones especiales',
        priceInCents: 42000,
        costInCents: 21000,
        isActive: true,
      ),
      quantity: 1,
    ),
    PosCartLine(
      product: Product(
        id: 'dense-product-3',
        categoryId: 'category-1',
        name: 'Refresco natural grande',
        priceInCents: 12000,
        costInCents: 6000,
        isActive: true,
      ),
      quantity: 1,
    ),
  ],
  cartLinesByTable: {
    'table-1': [
      PosCartLine(
        product: Product(
          id: 'dense-product-1',
          categoryId: 'category-1',
          name: 'Pollo asado familiar',
          priceInCents: 36000,
          costInCents: 18000,
          isActive: true,
        ),
        quantity: 2,
      ),
    ],
    'table-2': [
      PosCartLine(
        product: Product(
          id: 'dense-product-2',
          categoryId: 'category-1',
          name: 'Carne asada con guarniciones especiales',
          priceInCents: 42000,
          costInCents: 21000,
          isActive: true,
        ),
        quantity: 1,
      ),
    ],
  },
  selectedCategoryId: 'category-1',
  selectedPaymentMethodId: 'cash',
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
