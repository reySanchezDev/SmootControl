part of 'pos_bloc.dart';

void _registerPosHandlers(PosBloc bloc) {
  bloc
    ..on<PosStarted>((event, emit) => _handlePosStarted(bloc, event, emit))
    ..on<PosCashRegisterOpened>(
      (event, emit) => _handlePosCashRegisterOpened(bloc, event, emit),
    )
    ..on<PosCashRegisterClosed>(
      (event, emit) => _handlePosCashRegisterClosed(bloc, event, emit),
    )
    ..on<PosCategorySelected>(bloc._onCategorySelected)
    ..on<PosProductsReordered>(bloc._onProductsReordered)
    ..on<PosProductOrderReset>(bloc._onProductOrderReset)
    ..on<PosTablesReordered>(bloc._onTablesReordered)
    ..on<PosProductAdded>(
      (event, emit) => _handleProductAdded(bloc, event, emit),
    )
    ..on<PosProductRemoved>(
      (event, emit) => _handleProductRemoved(bloc, event, emit),
    )
    ..on<PosCartLineIncremented>(
      (event, emit) => _handleCartLineIncremented(bloc, event, emit),
    )
    ..on<PosCartLineDecremented>(
      (event, emit) => _handleCartLineDecremented(bloc, event, emit),
    )
    ..on<PosCartLineServedToggled>(
      (event, emit) => _handleCartLineServedToggled(bloc, event, emit),
    )
    ..on<PosModifierCatalogRefreshed>(bloc._onModifierCatalogRefreshed)
    ..on<PosPaymentMethodSelected>(bloc._onPaymentMethodSelected)
    ..on<PosSalesTypeSelected>(
      (event, emit) => _handleSalesTypeSelected(bloc, event, emit),
    )
    ..on<PosTableSelected>(
      (event, emit) => _handleTableSelected(bloc, event, emit),
    )
    ..on<PosTableDisplayNameChanged>(
      (event, emit) => _handleTableDisplayNameChanged(bloc, event, emit),
    )
    ..on<PosSplitAccountSelected>(
      (event, emit) => _handleSplitAccountSelected(bloc, event, emit),
    )
    ..on<PosAccountsSplitConfirmed>(
      (event, emit) => _handleAccountsSplitConfirmed(bloc, event, emit),
    )
    ..on<PosSplitAccountPaymentSelected>(bloc._onSplitAccountPaymentSelected)
    ..on<PosSplitAccountReferenceChanged>(
      bloc._onSplitAccountReferenceChanged,
    )
    ..on<PosCheckoutRequested>(
      (event, emit) => _handleCheckoutRequested(bloc, event, emit),
    )
    ..on<PosStaffConsumptionRequested>(
      (event, emit) => _handleStaffConsumptionRequested(bloc, event, emit),
    )
    ..on<PosCartCleared>(
      (event, emit) => _handleCartCleared(bloc, event, emit),
    );
}
