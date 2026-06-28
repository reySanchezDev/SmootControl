import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/payment_methods/domain/entities/payment_method.dart';

/// Data model for payment methods.
final class PaymentMethodModel extends Equatable {
  /// Creates a payment method model.
  const PaymentMethodModel({
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

  /// Creates a model from a local Drift row.
  factory PaymentMethodModel.fromLocal(LocalPaymentMethod row) {
    return PaymentMethodModel(
      id: row.id,
      name: row.name,
      parentId: row.parentId,
      groupName: row.groupName,
      currencyCode: row.currencyCode,
      displayOrder: row.displayOrder,
      isPaymentTarget: row.isPaymentTarget,
      affectsCashRegister: row.affectsCashRegister,
      requiresReference: row.requiresReference,
      isActive: row.isActive,
    );
  }

  /// Creates a model from a domain entity.
  factory PaymentMethodModel.fromEntity(PaymentMethod entity) {
    return PaymentMethodModel(
      id: entity.id,
      name: entity.name,
      parentId: entity.parentId,
      groupName: entity.groupName,
      currencyCode: entity.currencyCode,
      displayOrder: entity.displayOrder,
      isPaymentTarget: entity.isPaymentTarget,
      affectsCashRegister: entity.affectsCashRegister,
      requiresReference: entity.requiresReference,
      isActive: entity.isActive,
    );
  }

  /// Unique payment method identifier.
  final String id;

  /// Visible payment method name.
  final String name;

  /// Parent payment node identifier.
  final String? parentId;

  /// Visual group shown first in POS payment buttons.
  final String groupName;

  /// Optional currency code.
  final String? currencyCode;

  /// Sorting position in POS payment buttons.
  final int displayOrder;

  /// Whether this row completes payment.
  final bool isPaymentTarget;

  /// Whether this method affects physical cash.
  final bool affectsCashRegister;

  /// Whether a reference must be captured.
  final bool requiresReference;

  /// Whether the method can be used.
  final bool isActive;

  /// Converts this model to a domain entity.
  PaymentMethod toEntity() {
    return PaymentMethod(
      id: id,
      name: name,
      parentId: parentId,
      groupName: groupName,
      currencyCode: currencyCode,
      displayOrder: displayOrder,
      isPaymentTarget: isPaymentTarget,
      affectsCashRegister: affectsCashRegister,
      requiresReference: requiresReference,
      isActive: isActive,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    parentId,
    groupName,
    currencyCode,
    displayOrder,
    isPaymentTarget,
    affectsCashRegister,
    requiresReference,
    isActive,
  ];
}
