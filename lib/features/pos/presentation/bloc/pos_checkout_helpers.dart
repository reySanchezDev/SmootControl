part of 'pos_bloc.dart';

const String _failedCashSessionLookup = '__cash_session_lookup_failed__';

Future<String?> _openCashSessionId({
  required PosBloc bloc,
  required PosReady current,
  required Emitter<PosState> emit,
}) async {
  final session = current.openCashRegisterSession;
  if (session != null) return session.id;

  final result = await bloc._cashRegisterRepository.getOpenSessionForCashier(
    businessDate: DateTime.now(),
    cashierId: bloc._currentOperatorService.userId,
  );

  return switch (result) {
    AppSuccess(:final value) =>
      value?.id ??
          _emitCashSessionFailure(
            emit: emit,
            current: current,
            error: const AppFailure(
              code: 'pos_cash_register_required',
              message: 'Abre la caja diaria antes de cobrar.',
            ),
          ),
    AppFailureResult(:final error) => _emitCashSessionFailure(
      emit: emit,
      current: current,
      error: error,
    ),
  };
}

String _emitCashSessionFailure({
  required Emitter<PosState> emit,
  required PosReady current,
  required AppFailure error,
}) {
  emit(PosFailure(error));
  emit(current);
  return _failedCashSessionLookup;
}

final class _InvoiceReservation {
  const _InvoiceReservation(this.invoiceNumbers);

  final List<String> invoiceNumbers;
}

Future<_InvoiceReservation?> _prepareInvoiceNumbers({
  required PosBloc bloc,
  required int count,
  required PosReady current,
  required Emitter<PosState> emit,
}) async {
  final settingsResult = await bloc._settingsRepository.getSettings();
  final settings = switch (settingsResult) {
    AppSuccess(:final value) => value,
    AppFailureResult(:final error) => _emitReservationFailure(
      emit: emit,
      current: current,
      error: error,
    ),
  };

  if (settings == null) return null;

  final firstNumber = settings.nextInvoiceNumber < settings.initialInvoiceNumber
      ? settings.initialInvoiceNumber
      : settings.nextInvoiceNumber;
  final prefix = settings.invoicePrefix.trim().isEmpty
      ? BusinessSettings.empty.invoicePrefix
      : settings.invoicePrefix.trim().toUpperCase();
  final separator = prefix.endsWith('-') ? '' : '-';
  final numbers = [
    for (var index = 0; index < count; index += 1)
      '$prefix$separator${firstNumber + index}',
  ];

  return _InvoiceReservation(numbers);
}

Future<void> _commitInvoiceNumbers({
  required PosBloc bloc,
  required List<String> invoiceNumbers,
  required PosReady current,
  required Emitter<PosState> emit,
}) async {
  if (invoiceNumbers.isEmpty) return;

  final nextNumbers = invoiceNumbers
      .map(_nextInvoiceNumberAfter)
      .whereType<int>()
      .toList();
  if (nextNumbers.isEmpty) return;

  final settingsResult = await bloc._settingsRepository.getSettings();
  final currentSettings = switch (settingsResult) {
    AppSuccess(:final value) => value,
    AppFailureResult(:final error) => _emitReservationFailure(
      emit: emit,
      current: current,
      error: error,
    ),
  };
  if (currentSettings == null) return;

  final nextInvoiceNumber = nextNumbers.fold<int>(
    currentSettings.nextInvoiceNumber,
    (current, nextNumber) => nextNumber > current ? nextNumber : current,
  );
  if (nextInvoiceNumber == currentSettings.nextInvoiceNumber) return;

  final saveResult = await bloc._settingsRepository.saveSettings(
    currentSettings.copyWith(nextInvoiceNumber: nextInvoiceNumber),
    syncRemote: false,
  );
  switch (saveResult) {
    case AppSuccess():
      return;
    case AppFailureResult(:final error):
      _emitReservationFailure(emit: emit, current: current, error: error);
  }
}

int? _nextInvoiceNumberAfter(String invoiceNumber) {
  final match = RegExp(r'(\d+)$').firstMatch(invoiceNumber.trim());
  if (match == null) return null;
  final value = int.tryParse(match.group(1)!);
  if (value == null) return null;
  return value + 1;
}

BusinessSettings? _emitReservationFailure({
  required Emitter<PosState> emit,
  required PosReady current,
  required AppFailure error,
}) {
  emit(PosFailure(error));
  emit(current);
  return null;
}

Map<String, String> _salesTypesWithoutActiveOrder(PosReady current) {
  return Map<String, String>.from(current.salesTypeIdByOrderKey)
    ..remove(current.activeCartKey);
}

String _categoryName({
  required List<ProductCategory> categories,
  required String categoryId,
}) {
  for (final category in categories) {
    if (category.id == categoryId) return category.name;
  }

  return '';
}

AppFailure? _validateCheckout(PosReady state, String? reference) {
  if (state.cartLines.isEmpty) {
    return const AppFailure(
      code: 'pos_empty_cart',
      message: 'Agrega al menos un producto para facturar.',
    );
  }

  if (state.selectedSplitAccountId != null) {
    return _validateSingleSplitCheckout(state, reference);
  }

  if (state.hasSplitAccounts) {
    return _validateSplitCheckout(state);
  }

  final selectedMethod = state.selectedPaymentMethod;
  if (selectedMethod == null) {
    return const AppFailure(
      code: 'pos_payment_method_required',
      message: 'Selecciona un metodo de pago.',
    );
  }

  if (selectedMethod.requiresReference && (reference?.trim().isEmpty ?? true)) {
    return const AppFailure(
      code: 'pos_reference_required',
      message: 'Este metodo de pago requiere referencia.',
    );
  }

  return null;
}

AppFailure? _validateSingleSplitCheckout(PosReady state, String? reference) {
  final selectedMethod = state.selectedPaymentMethod;
  if (selectedMethod == null) {
    return const AppFailure(
      code: 'pos_payment_method_required',
      message: 'Selecciona un metodo de pago.',
    );
  }
  if (selectedMethod.requiresReference && (reference?.trim().isEmpty ?? true)) {
    return const AppFailure(
      code: 'pos_reference_required',
      message: 'Este metodo de pago requiere referencia.',
    );
  }
  return null;
}

AppFailure? _validateSplitCheckout(PosReady state) {
  for (final account in state.splitAccounts) {
    final method = _paymentMethodFor(
      methods: state.paymentMethods,
      methodId: account.paymentMethodId,
    );
    if (method == null) {
      return AppFailure(
        code: 'pos_split_payment_method_required',
        message: 'Selecciona metodo de pago para ${account.name}.',
      );
    }

    if (method.requiresReference &&
        (account.paymentReference?.trim().isEmpty ?? true)) {
      return AppFailure(
        code: 'pos_split_reference_required',
        message: 'Ingresa referencia de pago para ${account.name}.',
      );
    }
  }

  return null;
}

PaymentMethod? _paymentMethodFor({
  required List<PaymentMethod> methods,
  required String? methodId,
}) {
  for (final method in methods) {
    if (method.id == methodId) return method;
  }

  return null;
}
