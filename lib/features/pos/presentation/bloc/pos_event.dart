import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';

part 'pos_payment_checkout_events.dart';

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

/// Saves a local-only product order for one POS category.
final class PosProductsReordered extends PosEvent {
  /// Creates a product reorder event.
  const PosProductsReordered({
    required this.categoryId,
    required this.productIds,
  });

  /// Category whose visual product order changed.
  final String categoryId;

  /// Product identifiers in the new visual order.
  final List<String> productIds;

  @override
  List<Object?> get props => [categoryId, productIds];
}

/// Clears the local-only product order for one POS category.
final class PosProductOrderReset extends PosEvent {
  /// Creates a product order reset event.
  const PosProductOrderReset(this.categoryId);

  /// Category whose local visual order is reset.
  final String categoryId;

  @override
  List<Object?> get props => [categoryId];
}

/// Saves a local-only table order for the POS table band.
final class PosTablesReordered extends PosEvent {
  /// Creates a table reorder event.
  const PosTablesReordered({
    required this.tableIds,
  });

  /// Physical table identifiers in the new visual order.
  final List<String> tableIds;

  @override
  List<Object?> get props => [tableIds];
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
