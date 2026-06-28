import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/catalog/domain/entities/product_category.dart';
import 'package:smoo_control/features/modifiers/domain/entities/modifier_catalog.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';
import 'package:smoo_control/features/pos/domain/entities/account_split_draft.dart';
import 'package:smoo_control/features/pos/domain/entities/pos_cart_line.dart';
import 'package:smoo_control/features/pos/domain/services/pos_option_group_resolver.dart';
import 'package:smoo_control/features/products/domain/entities/product.dart';
import 'package:smoo_control/features/products/domain/entities/product_option_group.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item_draft.dart';
import 'package:smoo_control/features/tables/domain/entities/restaurant_table.dart';

part 'pos_ready_state.dart';

/// Base POS state.
sealed class PosState extends Equatable {
  /// Creates a POS state.
  const PosState();

  @override
  List<Object?> get props => [];
}

/// Initial POS state.
final class PosInitial extends PosState {
  /// Creates the initial state.
  const PosInitial();
}

/// POS loading state.
final class PosLoading extends PosState {
  /// Creates a loading state.
  const PosLoading();
}

/// POS state shown when the current operator has no open cash register.
final class PosCashRegisterRequired extends PosState {
  /// Creates a cash-register-required state.
  const PosCashRegisterRequired();
}

/// POS state shown when the current operator left a past cash register open.
final class PosStaleCashRegisterRequired extends PosState {
  /// Creates a stale cash-register-required state.
  const PosStaleCashRegisterRequired(this.session);

  /// Past open cash register session that must be closed first.
  final CashRegisterSession session;

  @override
  List<Object?> get props => [session];
}

/// POS failure state.
final class PosFailure extends PosState {
  /// Creates a failure state.
  const PosFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
