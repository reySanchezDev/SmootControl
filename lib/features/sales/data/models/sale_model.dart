import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';

/// Data model for completed or voided sales.
final class SaleModel extends Equatable {
  /// Creates a sale model.
  const SaleModel({
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
    this.tableId,
    this.tableAccountId,
    this.cashRegisterSessionId,
    this.salesTypeId,
    this.salesTypeName,
    this.paymentReference,
    this.paymentCurrencyCode,
    this.exchangeRateInCents,
    this.employeeId,
    this.internalReceiptNumber,
    this.payrollRunId,
  });

  /// Creates a model from a local Drift row.
  factory SaleModel.fromLocal(LocalSale row) {
    return SaleModel(
      id: row.id,
      invoiceNumber: row.invoiceNumber,
      saleKind: _saleKindFromText(row.saleKind),
      tableId: row.tableId,
      tableAccountId: row.tableAccountId,
      cashRegisterSessionId: row.cashRegisterSessionId,
      paymentMethodId: row.paymentMethodId,
      salesTypeId: row.salesTypeId,
      salesTypeName: row.salesTypeName,
      employeeId: row.employeeId,
      internalReceiptNumber: row.internalReceiptNumber,
      payrollRunId: row.payrollRunId,
      paymentReference: row.paymentReference,
      paymentCurrencyCode: row.paymentCurrencyCode,
      exchangeRateInCents: row.exchangeRateInCents,
      status: _statusFromText(row.status),
      subtotalInCents: row.subtotalInCents,
      totalInCents: row.totalInCents,
      createdAt: row.createdAt,
      syncStatus: _syncStatusFromText(row.syncStatus),
      syncError: row.syncError,
    );
  }

  /// Creates a model from a domain entity.
  factory SaleModel.fromEntity(Sale entity) {
    return SaleModel(
      id: entity.id,
      invoiceNumber: entity.invoiceNumber,
      saleKind: entity.saleKind,
      tableId: entity.tableId,
      tableAccountId: entity.tableAccountId,
      cashRegisterSessionId: entity.cashRegisterSessionId,
      paymentMethodId: entity.paymentMethodId,
      salesTypeId: entity.salesTypeId,
      salesTypeName: entity.salesTypeName,
      employeeId: entity.employeeId,
      internalReceiptNumber: entity.internalReceiptNumber,
      payrollRunId: entity.payrollRunId,
      paymentReference: entity.paymentReference,
      paymentCurrencyCode: entity.paymentCurrencyCode,
      exchangeRateInCents: entity.exchangeRateInCents,
      status: entity.status,
      subtotalInCents: entity.subtotalInCents,
      totalInCents: entity.totalInCents,
      createdAt: entity.createdAt,
      syncStatus: entity.syncStatus,
      syncError: entity.syncError,
    );
  }

  /// Unique sale identifier.
  final String id;

  /// Sequential invoice or receipt number.
  final String invoiceNumber;

  /// Business meaning for this sale row.
  final SaleKind saleKind;

  /// Original table identifier.
  final String? tableId;

  /// Split account identifier.
  final String? tableAccountId;

  /// Daily cash register session identifier.
  final String? cashRegisterSessionId;

  /// Payment method identifier.
  final String paymentMethodId;

  /// Selected sales type identifier.
  final String? salesTypeId;

  /// Historical selected sales type name.
  final String? salesTypeName;

  /// Employee linked to staff consumption.
  final String? employeeId;

  /// Remote internal receipt sequence.
  final int? internalReceiptNumber;

  /// Payroll run that applied this consumption.
  final String? payrollRunId;

  /// Captured payment reference.
  final String? paymentReference;

  /// Historical payment currency.
  final String? paymentCurrencyCode;

  /// Historical exchange rate in minor currency units.
  final int? exchangeRateInCents;

  /// Current sale status.
  final SaleStatus status;

  /// Sale subtotal.
  final int subtotalInCents;

  /// Sale total.
  final int totalInCents;

  /// Local creation date.
  final DateTime createdAt;

  /// Current synchronization state.
  final SaleSyncStatus syncStatus;

  /// Last synchronization error captured for this sale.
  final String? syncError;

  /// Database value for status.
  String get statusValue => status.name;

  /// Database value for sale kind.
  String get saleKindValue => switch (saleKind) {
    SaleKind.sale => 'sale',
    SaleKind.staffConsumption => 'staff_consumption',
  };

  /// Database value for sync status.
  String get syncStatusValue => syncStatus.name;

  /// Creates a modified copy.
  SaleModel copyWith({
    String? invoiceNumber,
    int? internalReceiptNumber,
    SaleSyncStatus? syncStatus,
    String? syncError,
  }) {
    return SaleModel(
      id: id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      saleKind: saleKind,
      tableId: tableId,
      tableAccountId: tableAccountId,
      cashRegisterSessionId: cashRegisterSessionId,
      paymentMethodId: paymentMethodId,
      salesTypeId: salesTypeId,
      salesTypeName: salesTypeName,
      employeeId: employeeId,
      internalReceiptNumber:
          internalReceiptNumber ?? this.internalReceiptNumber,
      payrollRunId: payrollRunId,
      paymentReference: paymentReference,
      paymentCurrencyCode: paymentCurrencyCode,
      exchangeRateInCents: exchangeRateInCents,
      status: status,
      subtotalInCents: subtotalInCents,
      totalInCents: totalInCents,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
    );
  }

  /// Converts this model to a domain entity.
  Sale toEntity() {
    return Sale(
      id: id,
      invoiceNumber: invoiceNumber,
      saleKind: saleKind,
      tableId: tableId,
      tableAccountId: tableAccountId,
      cashRegisterSessionId: cashRegisterSessionId,
      paymentMethodId: paymentMethodId,
      salesTypeId: salesTypeId,
      salesTypeName: salesTypeName,
      employeeId: employeeId,
      internalReceiptNumber: internalReceiptNumber,
      payrollRunId: payrollRunId,
      paymentReference: paymentReference,
      paymentCurrencyCode: paymentCurrencyCode,
      exchangeRateInCents: exchangeRateInCents,
      status: status,
      subtotalInCents: subtotalInCents,
      totalInCents: totalInCents,
      createdAt: createdAt,
      syncStatus: syncStatus,
      syncError: syncError,
    );
  }

  static SaleStatus _statusFromText(String value) {
    return SaleStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SaleStatus.completed,
    );
  }

  static SaleKind _saleKindFromText(String value) {
    return switch (value) {
      'staff_consumption' => SaleKind.staffConsumption,
      _ => SaleKind.sale,
    };
  }

  static SaleSyncStatus _syncStatusFromText(String value) {
    return SaleSyncStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SaleSyncStatus.pending,
    );
  }

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
