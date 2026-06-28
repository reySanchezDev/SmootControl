part of 'pos_bloc.dart';

void _handleAccountsSplitConfirmed(
  PosBloc bloc,
  PosAccountsSplitConfirmed event,
  Emitter<PosState> emit,
) {
  final current = bloc.state;
  if (current is! PosReady) return;

  final tableId = current.selectedTableId;
  if (tableId == null) {
    emit(
      const PosFailure(
        AppFailure(
          code: 'split_table_required',
          message: 'Selecciona una mesa antes de separar cuentas.',
        ),
      ),
    );
    emit(current);
    return;
  }

  final sameTable = event.accounts.every((account) {
    return account.tableId == tableId;
  });
  if (!sameTable) {
    emit(
      const PosFailure(
        AppFailure(
          code: 'split_table_mismatch',
          message: 'Las cuentas deben pertenecer a la mesa seleccionada.',
        ),
      ),
    );
    emit(current);
    return;
  }

  final result = bloc._accountSeparationService.validate(
    tableItems: current.splitDraftItems,
    accounts: event.accounts,
  );
  switch (result) {
    case AppSuccess(:final value):
      final accounts = [
        for (final account in value)
          account.copyWith(
            paymentMethodId: current.selectedPaymentMethodId,
          ),
      ];
      final accountsByTable = Map<String, List<AccountSplitDraft>>.of(
        current.splitAccountsByTable,
      )..[tableId] = accounts;
      final sourceLinesByTable = Map<String, List<PosCartLine>>.of(
        current.splitSourceLinesByTable,
      )..[tableId] = current.cartLines;
      emit(
        current.copyWith(
          cartLines: const [],
          cartLinesByTable: _cartsWithActiveCart(current, const []),
          splitAccounts: accounts,
          splitAccountsByTable: accountsByTable,
          splitSourceLinesByTable: sourceLinesByTable,
          clearSelectedSplitAccount: true,
          clearLastCompletedSale: true,
        ),
      );
    case AppFailureResult(:final error):
      emit(PosFailure(error));
      emit(current);
  }
}
