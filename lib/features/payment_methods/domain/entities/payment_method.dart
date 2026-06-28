import 'package:equatable/equatable.dart';

/// Payment method configured for the restaurant.
final class PaymentMethod extends Equatable {
  /// Creates a payment method.
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.affectsCashRegister,
    required this.requiresReference,
    required this.isActive,
    this.parentId,
    this.groupName = 'Otros',
    this.currencyCode,
    this.displayOrder = 0,
    this.isPaymentTarget = true,
  });

  /// Unique payment method identifier.
  final String id;

  /// Visible payment method name.
  final String name;

  /// Parent payment node when this method is nested.
  final String? parentId;

  /// Visual group shown first in the POS payment action panel.
  final String groupName;

  /// Optional currency code for cash or transfer methods.
  final String? currencyCode;

  /// Sorting position in POS payment buttons.
  final int displayOrder;

  /// Whether this node completes a payment when selected.
  final bool isPaymentTarget;

  /// Whether payments with this method affect physical cash.
  final bool affectsCashRegister;

  /// Whether a payment reference is required.
  final bool requiresReference;

  /// Whether the method is available for new sales.
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    name,
    parentId,
    affectsCashRegister,
    requiresReference,
    isActive,
    groupName,
    currencyCode,
    displayOrder,
    isPaymentTarget,
  ];
}
