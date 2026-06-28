import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_session.dart';
import 'package:smoo_control/features/cash_register/domain/entities/cash_register_summary.dart';

/// Base cash register state.
sealed class CashRegisterState extends Equatable {
  /// Creates a cash register state.
  const CashRegisterState();

  @override
  List<Object?> get props => [];
}

/// Initial cash register state.
final class CashRegisterInitial extends CashRegisterState {
  /// Creates the initial state.
  const CashRegisterInitial();
}

/// Cash register loading state.
final class CashRegisterLoading extends CashRegisterState {
  /// Creates a loading state.
  const CashRegisterLoading();
}

/// Cash register operation success state.
final class CashRegisterSuccess extends CashRegisterState {
  /// Creates a success state.
  const CashRegisterSuccess(this.summary);

  /// Current calculated summary.
  final CashRegisterSummary summary;

  /// Current session.
  CashRegisterSession get session => summary.session;

  @override
  List<Object?> get props => [summary];
}

/// Cash register failure state.
final class CashRegisterFailure extends CashRegisterState {
  /// Creates a failure state.
  const CashRegisterFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
