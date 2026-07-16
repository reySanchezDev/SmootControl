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

/// Business meaning for a local sale row.
enum SaleKind {
  /// Normal customer sale.
  sale,

  /// Internal staff consumption that deducts stock but is not fiscal revenue.
  staffConsumption,
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
    this.saleKind = SaleKind.sale,
    this.syncStatus = SaleSyncStatus.pending,
    this.syncError,
    this.paymentReference,
    this.paymentCurrencyCode,
    this.exchangeRateInCents,
    this.tableId,
    this.tableAccountId,
    this.cashRegisterSessionId,
    this.salesTypeId,
    this.salesTypeName,
    this.employeeId,
    this.internalReceiptNumber,
    this.payrollRunId,
  });

  /// Unique sale identifier.
  final String id;

  /// Sequential invoice or receipt number.
  final String invoiceNumber;

  /// Business meaning for this row.
  final SaleKind saleKind;

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

  /// Employee linked to an internal staff consumption.
  final String? employeeId;

  /// Remote staff-consumption consecutive.
  final int? internalReceiptNumber;

  /// Payroll run that applied this internal consumption.
  final String? payrollRunId;

  /// Optional payment reference.
  final String? paymentReference;

  /// Historical payment currency used for the sale.
  final String? paymentCurrencyCode;

  /// Historical exchange rate used for the sale.
  final int? exchangeRateInCents;

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

  /// Last synchronization error captured for this sale.
  final String? syncError;

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    saleKind,
    tableId,
    tableAccountId,
    cashRegisterSessionId,
    paymentMethodId,
    salesTypeId,
    salesTypeName,
    employeeId,
    internalReceiptNumber,
    payrollRunId,
    paymentReference,
    paymentCurrencyCode,
    exchangeRateInCents,
    status,
    subtotalInCents,
    totalInCents,
    createdAt,
    syncStatus,
    syncError,
  ];
}
