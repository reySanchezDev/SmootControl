import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/result/app_failure.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';

/// Base payment methods state.
sealed class PaymentMethodsState extends Equatable {
  /// Creates a payment methods state.
  const PaymentMethodsState();

  @override
  List<Object?> get props => [];
}

/// Initial payment methods state.
final class PaymentMethodsInitial extends PaymentMethodsState {
  /// Creates the initial state.
  const PaymentMethodsInitial();
}

/// Payment methods loading state.
final class PaymentMethodsLoading extends PaymentMethodsState {
  /// Creates a loading state.
  const PaymentMethodsLoading();
}

/// Payment methods loaded state.
final class PaymentMethodsLoaded extends PaymentMethodsState {
  /// Creates a loaded state.
  const PaymentMethodsLoaded(this.methods);

  /// Available payment methods.
  final List<PaymentMethod> methods;

  @override
  List<Object?> get props => [methods];
}

/// Payment methods failure state.
final class PaymentMethodsFailure extends PaymentMethodsState {
  /// Creates a failure state.
  const PaymentMethodsFailure(this.failure);

  /// Failure details.
  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
