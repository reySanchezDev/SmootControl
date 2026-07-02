import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

/// Base POS event.
sealed class PosEvent extends Equatable {
  /// Creates a POS event.
  const PosEvent();

  @override
  List<Object?> get props => [];
}

/// Loads products and payment methods for checkout.
final class PosStarted extends PosEvent {
  /// Creates a POS start event.
  const PosStarted();
}

/// Opens the cash register required to operate the POS.
final class PosCashRegisterOpened extends PosEvent {
  /// Creates a cash register open event.
  const PosCashRegisterOpened(this.session);

  /// Session to open for the current operator.
  final CashRegisterSession session;

  @override
  List<Object?> get props => [session];
}

/// Closes the current POS cash register.
final class PosCashRegisterClosed extends PosEvent {
  /// Creates a cash register close event.
  const PosCashRegisterClosed({
    required this.physicalClosingCashInCents,
  });

  /// Physical cash declared by the cashier.
  final int physicalClosingCashInCents;

  @override
  List<Object?> get props => [physicalClosingCashInCents];
}

/// Adds a product to the cart.
final class PosProductAdded extends PosEvent {
  /// Creates a product added event.
  const PosProductAdded(
    this.product, {
    this.selectedOptions = const [],
  });

  /// Product to add.
  final Product product;

  /// Options selected before adding the product.
  final List<SelectedProductOption> selectedOptions;

  @override
  List<Object?> get props => [product, selectedOptions];
}

/// Selects a category or returns to the root category list.
final class PosCategorySelected extends PosEvent {
  /// Creates a category selected event.
  const PosCategorySelected(this.categoryId);

  /// Category identifier, or null for the root category list.
  final String? categoryId;

  @override
  List<Object?> get props => [categoryId];
}

/// Removes a product from the cart.
final class PosProductRemoved extends PosEvent {
  /// Creates a product removed event.
  const PosProductRemoved(this.cartLineKey);

  /// Cart line identifier.
  final String cartLineKey;

  @override
  List<Object?> get props => [cartLineKey];
}

/// Increases the quantity of a cart line.
final class PosCartLineIncremented extends PosEvent {
  /// Creates a cart line increment event.
  const PosCartLineIncremented(this.cartLineKey);

  /// Cart line identifier.
  final String cartLineKey;

  @override
  List<Object?> get props => [cartLineKey];
}

/// Decreases the quantity of a cart line.
final class PosCartLineDecremented extends PosEvent {
  /// Creates a cart line decrement event.
  const PosCartLineDecremented(this.cartLineKey);

  /// Cart line identifier.
  final String cartLineKey;

  @override
  List<Object?> get props => [cartLineKey];
}

/// Toggles whether a cart line has already been served.
final class PosCartLineServedToggled extends PosEvent {
  /// Creates a served toggle event.
  const PosCartLineServedToggled(this.cartLineKey);

  /// Cart line identifier.
  final String cartLineKey;

  @override
  List<Object?> get props => [cartLineKey];
}

/// Refreshes reusable modifier availability in the active POS.
final class PosModifierCatalogRefreshed extends PosEvent {
  /// Creates a modifier catalog refresh event.
  const PosModifierCatalogRefreshed(this.catalog);

  /// Updated modifier catalog.
  final ModifierCatalog catalog;

  @override
  List<Object?> get props => [catalog];
}

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
  const PosCheckoutRequested({this.paymentReference});

  /// Optional payment reference.
  final String? paymentReference;

  @override
  List<Object?> get props => [paymentReference];
}

/// Clears the POS cart.
final class PosCartCleared extends PosEvent {
  /// Creates a cart cleared event.
  const PosCartCleared();
}
