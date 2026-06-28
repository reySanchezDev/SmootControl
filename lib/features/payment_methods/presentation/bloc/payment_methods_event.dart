import 'package:equatable/equatable.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';

/// Base event for payment methods state management.
sealed class PaymentMethodsEvent extends Equatable {
  /// Creates a payment methods event.
  const PaymentMethodsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads payment methods.
final class PaymentMethodsLoadRequested extends PaymentMethodsEvent {
  /// Creates a load event.
  const PaymentMethodsLoadRequested();
}

/// Saves a payment method.
final class PaymentMethodSaved extends PaymentMethodsEvent {
  /// Creates a save event.
  const PaymentMethodSaved(this.method);

  /// Payment method to persist.
  final PaymentMethod method;

  @override
  List<Object?> get props => [method];
}

/// Removes a nested payment level.
final class PaymentMethodRemoved extends PaymentMethodsEvent {
  /// Creates a remove event.
  const PaymentMethodRemoved(this.method);

  /// Payment method level to remove.
  final PaymentMethod method;

  @override
  List<Object?> get props => [method];
}
