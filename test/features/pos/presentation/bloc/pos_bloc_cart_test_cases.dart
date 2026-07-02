part of 'pos_bloc_test.dart';

void registerCartTests({
  required PosBloc Function() buildBloc,
  required PaymentMethod method,
  required Product product,
  required RestaurantTable table,
}) {
  blocTest<PosBloc, PosState>(
    'adds products to cart',
    build: buildBloc,
    seed: () => PosReady(
      products: [product],
      tables: [table],
      paymentMethods: [method],
      selectedPaymentMethodId: method.id,
      selectedTableId: table.id,
    ),
    act: (bloc) => bloc.add(PosProductAdded(product)),
    expect: () => [
      isA<PosReady>().having(
        (state) => state.cartLines.single.quantity,
        'quantity',
        1,
      ),
    ],
  );

  blocTest<PosBloc, PosState>(
    'shows a clear message before adding products without a table',
    build: buildBloc,
    seed: () => PosReady(
      products: [product],
      tables: [table],
      paymentMethods: [method],
      selectedPaymentMethodId: method.id,
    ),
    act: (bloc) => bloc.add(PosProductAdded(product)),
    expect: () => [
      isA<PosFailure>().having(
        (state) => state.failure.message,
        'message',
        'Selecciona una mesa antes de agregar productos al pedido.',
      ),
      isA<PosReady>().having(
        (state) => state.cartLines,
        'cart remains empty',
        isEmpty,
      ),
    ],
  );

  blocTest<PosBloc, PosState>(
    'increments and decrements cart line quantity',
    build: buildBloc,
    seed: () => PosReady(
      products: [product],
      tables: [table],
      paymentMethods: [method],
      cartLines: [PosCartLine(product: product, quantity: 1)],
      selectedPaymentMethodId: method.id,
    ),
    act: (bloc) {
      bloc
        ..add(PosCartLineIncremented(product.idWithEmptyOptions))
        ..add(PosCartLineDecremented(product.idWithEmptyOptions));
    },
    expect: () => [
      isA<PosReady>().having(
        (state) => state.cartLines.single.quantity,
        'incremented quantity',
        2,
      ),
      isA<PosReady>().having(
        (state) => state.cartLines.single.quantity,
        'decremented quantity',
        1,
      ),
    ],
  );

  blocTest<PosBloc, PosState>(
    'keeps an independent cart for each selected table',
    build: buildBloc,
    seed: () {
      const secondTable = RestaurantTable(
        id: 'table-2',
        name: 'Mesa 2',
        status: RestaurantTableStatus.available,
        isActive: true,
      );
      return PosReady(
        products: [product],
        tables: [table, secondTable],
        paymentMethods: [method],
        selectedPaymentMethodId: method.id,
      );
    },
    act: (bloc) {
      bloc
        ..add(PosTableSelected(table.id))
        ..add(PosProductAdded(product))
        ..add(const PosTableSelected('table-2'))
        ..add(PosProductAdded(product))
        ..add(PosProductAdded(product))
        ..add(PosTableSelected(table.id));
    },
    expect: () => [
      isA<PosReady>().having(
        (state) => state.selectedTableId,
        'selected table',
        table.id,
      ),
      isA<PosReady>().having(
        (state) => state.cartLines.single.quantity,
        'table one quantity',
        1,
      ),
      isA<PosReady>().having(
        (state) => state.selectedTableId,
        'selected table',
        'table-2',
      ),
      isA<PosReady>().having(
        (state) => state.cartLines.single.quantity,
        'table two quantity',
        1,
      ),
      isA<PosReady>().having(
        (state) => state.cartLines.single.quantity,
        'table two incremented quantity',
        2,
      ),
      isA<PosReady>().having(
        (state) => state.cartLines.single.quantity,
        'table one restored quantity',
        1,
      ),
    ],
  );
}

extension _ProductCartTestKey on Product {
  String get idWithEmptyOptions => id;
}
