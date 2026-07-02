import 'package:equatable/equatable.dart';

/// Sale lifecycle state.
enum SaleStatus {
  /// Sale was completed and is valid.
  completed,

  /// Sale was voided and must remain auditable.
  voided,
}

/// Local remote synchronization state for one sale.
enum SaleSyncStatus {
  /// Waiting to be synchronized.
  pending,

  /// Currently being synchronized.
  syncing,

  /// Successfully synchronized remotely.
  synced,

  /// Failed and waiting for retry.
  error,
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
    this.syncStatus = SaleSyncStatus.pending,
    this.paymentReference,
    this.tableId,
    this.tableAccountId,
    this.cashRegisterSessionId,
    this.salesTypeId,
    this.salesTypeName,
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

  /// Selected sales type identifier.
  final String? salesTypeId;

  /// Historical selected sales type name.
  final String? salesTypeName;

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

  /// Remote synchronization state.
  final SaleSyncStatus syncStatus;

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    tableId,
    tableAccountId,
    cashRegisterSessionId,
    paymentMethodId,
    salesTypeId,
    salesTypeName,
    paymentReference,
    status,
    subtotalInCents,
    totalInCents,
    createdAt,
    syncStatus,
  ];
}
