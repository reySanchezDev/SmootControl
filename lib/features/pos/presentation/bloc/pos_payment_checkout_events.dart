part of 'pos_event.dart';

/// Selects a payment method.
final class PosPaymentMethodSelected extends PosEvent {
  /// Creates a payment method selected event.
  const PosPaymentMethodSelected(this.paymentMethodId);

  /// Payment method identifier.
  final String paymentMethodId;

  @override
  List<Object?> get props => [paymentMethodId];
}

/// Selects the current order sales type.
final class PosSalesTypeSelected extends PosEvent {
  /// Creates a sales type selected event.
  const PosSalesTypeSelected(this.salesTypeId);

  /// Sales type identifier.
  final String salesTypeId;

  @override
  List<Object?> get props => [salesTypeId];
}

/// Selects the current table for the sale.
final class PosTableSelected extends PosEvent {
  /// Creates a table selected event.
  const PosTableSelected(this.tableId);

  /// Table identifier, or null when selling without table.
  final String? tableId;

  @override
  List<Object?> get props => [tableId];
}

/// Updates the temporary POS name shown for a physical table.
final class PosTableDisplayNameChanged extends PosEvent {
  /// Creates a table display-name change event.
  const PosTableDisplayNameChanged({
    required this.tableId,
    required this.displayName,
  });

  /// Physical table identifier.
  final String tableId;

  /// Temporary name shown in POS until the table is released.
  final String displayName;

  @override
  List<Object?> get props => [tableId, displayName];
}

/// Selects a child account created from a table separation.
final class PosSplitAccountSelected extends PosEvent {
  /// Creates a child account selection event.
  const PosSplitAccountSelected({
    required this.tableId,
    required this.accountId,
  });

  /// Original table identifier.
  final String tableId;

  /// Child account identifier.
  final String accountId;

  @override
  List<Object?> get props => [tableId, accountId];
}

/// Confirms a validated split-account assignment.
final class PosAccountsSplitConfirmed extends PosEvent {
  /// Creates a split accounts confirmed event.
  const PosAccountsSplitConfirmed(this.accounts);

  /// Accounts with assigned draft item identifiers.
  final List<AccountSplitDraft> accounts;

  @override
  List<Object?> get props => [accounts];
}

/// Selects a payment method for a split account.
final class PosSplitAccountPaymentSelected extends PosEvent {
  /// Creates a split account payment selection event.
  const PosSplitAccountPaymentSelected({
    required this.accountId,
    required this.paymentMethodId,
  });

  /// Split account identifier.
  final String accountId;

  /// Payment method identifier.
  final String paymentMethodId;

  @override
  List<Object?> get props => [accountId, paymentMethodId];
}

/// Updates the payment reference for a split account.
final class PosSplitAccountReferenceChanged extends PosEvent {
  /// Creates a split account reference change event.
  const PosSplitAccountReferenceChanged({
    required this.accountId,
    required this.reference,
  });

  /// Split account identifier.
  final String accountId;

  /// Payment reference value.
  final String reference;

  @override
  List<Object?> get props => [accountId, reference];
}

/// Completes the current sale.
final class PosCheckoutRequested extends PosEvent {
  /// Creates a checkout event.
  const PosCheckoutRequested({
    this.paymentReference,
    this.paymentCurrencyCode,
    this.exchangeRateInCents,
  });

  /// Optional payment reference.
  final String? paymentReference;

  /// Historical payment currency used at checkout.
  final String? paymentCurrencyCode;

  /// Historical exchange rate used at checkout.
  final int? exchangeRateInCents;

  @override
  List<Object?> get props => [
    paymentReference,
    paymentCurrencyCode,
    exchangeRateInCents,
  ];
}

/// Saves the current cart as staff consumption.
final class PosStaffConsumptionRequested extends PosEvent {
  /// Creates the event.
  const PosStaffConsumptionRequested({
    required this.employeeId,
    required this.deliveredAt,
  });

  /// Employee that receives the consumption.
  final String employeeId;

  /// Date when the consumption was delivered.
  final DateTime deliveredAt;

  @override
  List<Object?> get props => [employeeId, deliveredAt];
}

/// Clears the POS cart.
final class PosCartCleared extends PosEvent {
  /// Creates a cart cleared event.
  const PosCartCleared();
}
