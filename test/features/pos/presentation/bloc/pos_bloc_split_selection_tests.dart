part of 'pos_bloc_split_test.dart';

void _splitSelectionTests() {
  blocTest<PosBloc, PosState>(
    'keeps original table empty after selecting a split table',
    build: _buildBloc,
    seed: () => const PosReady(
      products: [_product],
      tables: [_table],
      paymentMethods: [_cashMethod],
      splitSourceLinesByTable: {
        'table-1': [PosCartLine(product: _product, quantity: 2)],
      },
      splitAccountsByTable: {'table-1': _splitAccounts},
    ),
    act: (bloc) => bloc.add(const PosTableSelected('table-1')),
    expect: () => [
      isA<PosReady>()
          .having((state) => state.splitAccounts.length, 'accounts', 2)
          .having((state) => state.cartLines, 'cart lines', isEmpty),
    ],
  );

  blocTest<PosBloc, PosState>(
    'loads only a selected split account for checkout',
    build: _buildBloc,
    seed: () => const PosReady(
      products: [_product],
      tables: [_table],
      paymentMethods: [_cashMethod],
      splitSourceLinesByTable: {
        'table-1': [PosCartLine(product: _product, quantity: 2)],
      },
      splitAccountsByTable: {'table-1': _splitAccounts},
    ),
    act: (bloc) => bloc.add(
      const PosSplitAccountSelected(
        tableId: 'table-1',
        accountId: 'account-2',
      ),
    ),
    expect: () => [
      isA<PosReady>()
          .having(
            (state) => state.selectedSplitAccountId,
            'account',
            'account-2',
          )
          .having((state) => state.cartLines.single.quantity, 'quantity', 1),
    ],
  );

  blocTest<PosBloc, PosState>(
    'checks out only the selected split account',
    build: _buildBloc,
    seed: () => const PosReady(
      products: [_product],
      tables: [_table],
      paymentMethods: [_cashMethod],
      cartLines: [PosCartLine(product: _product, quantity: 1)],
      splitAccounts: _splitAccounts,
      splitAccountsByTable: {'table-1': _splitAccounts},
      splitSourceLinesByTable: {
        'table-1': [PosCartLine(product: _product, quantity: 2)],
      },
      selectedTableId: 'table-1',
      selectedSplitAccountId: 'account-1',
      selectedPaymentMethodId: 'cash',
    ),
    act: (bloc) => bloc.add(const PosCheckoutRequested()),
    expect: () => [
      isA<PosReady>()
          .having((state) => state.lastCompletedSales.length, 'sales', 1)
          .having((state) => state.splitAccounts.length, 'remaining', 1)
          .having((state) => state.cartLines, 'cart', isEmpty),
    ],
  );
}
