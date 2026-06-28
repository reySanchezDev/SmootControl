import 'package:equatable/equatable.dart';

/// Sale lifecycle state.
enum SaleStatus {
  /// Sale was completed and is valid.
  completed,

  /// Sale was voided and must remain auditable.
  voided,
}

/// Completed sale summary.
final class Sale extends Equatable {
  /// Creates a sale.
  const Sale({
    required this.id,
    required this.invoiceNumber,
    required this.paymentMethodId,
    required this.status,
    required this.subtotalInCents,
    required this.totalInCents,
    required this.createdAt,
    this.paymentReference,
    this.tableId,
    this.tableAccountId,
    this.cashRegisterSessionId,
  });

  /// Unique sale identifier.
  final String id;

  /// Sequential invoice or receipt number.
  final String invoiceNumber;

  /// Original table identifier when the sale came from a table.
  final String? tableId;

  /// Split account identifier when applicable.
  final String? tableAccountId;

  /// Daily cash register session identifier when applicable.
  final String? cashRegisterSessionId;

  /// Payment method identifier.
  final String paymentMethodId;

  /// Optional payment reference.
  final String? paymentReference;

  /// Sale state.
  final SaleStatus status;

  /// Sale subtotal.
  final int subtotalInCents;

  /// Total sale amount.
  final int totalInCents;

  /// Sale creation date.
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    tableId,
    tableAccountId,
    cashRegisterSessionId,
    paymentMethodId,
    paymentReference,
    status,
    subtotalInCents,
    totalInCents,
    createdAt,
  ];
}
