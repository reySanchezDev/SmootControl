part of 'pos_bloc_test.dart';

void registerCashRegisterCheckoutTests({
  required PosBloc Function({
    ICashRegisterRepository? cashRegisterRepository,
  })
  buildBloc,
  required PaymentMethod method,
  required Product product,
  required RestaurantTable table,
}) {
  blocTest<PosBloc, PosState>(
    'blocks checkout when daily cash register is not open',
    build: () => buildBloc(
      cashRegisterRepository: const _CashRegisterRepositoryFake(null),
    ),
    seed: () => PosReady(
      products: [product],
      tables: [table],
      paymentMethods: [method],
      cartLines: [PosCartLine(product: product, quantity: 1)],
      selectedPaymentMethodId: 'cash',
    ),
    act: (bloc) => bloc.add(const PosCheckoutRequested()),
    expect: () => [
      isA<PosFailure>().having(
        (state) => state.failure.code,
        'code',
        'pos_cash_register_required',
      ),
      isA<PosReady>().having(
        (state) => state.cartLines,
        'cart is preserved',
        isNotEmpty,
      ),
    ],
  );
}
