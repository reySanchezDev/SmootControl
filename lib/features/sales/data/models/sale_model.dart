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
    this.syncStatus = SaleSyncStatus.pending,
    this.tableId,
    this.tableAccountId,
    this.cashRegisterSessionId,
    this.paymentReference,
  });

  /// Creates a model from a local Drift row.
  factory SaleModel.fromLocal(LocalSale row) {
    return SaleModel(
      id: row.id,
      invoiceNumber: row.invoiceNumber,
      tableId: row.tableId,
      tableAccountId: row.tableAccountId,
      cashRegisterSessionId: row.cashRegisterSessionId,
      paymentMethodId: row.paymentMethodId,
      paymentReference: row.paymentReference,
      status: _statusFromText(row.status),
      subtotalInCents: row.subtotalInCents,
      totalInCents: row.totalInCents,
      createdAt: row.createdAt,
      syncStatus: _syncStatusFromText(row.syncStatus),
    );
  }

  /// Creates a model from a domain entity.
  factory SaleModel.fromEntity(Sale entity) {
    return SaleModel(
      id: entity.id,
      invoiceNumber: entity.invoiceNumber,
      tableId: entity.tableId,
      tableAccountId: entity.tableAccountId,
      cashRegisterSessionId: entity.cashRegisterSessionId,
      paymentMethodId: entity.paymentMethodId,
      paymentReference: entity.paymentReference,
      status: entity.status,
      subtotalInCents: entity.subtotalInCents,
      totalInCents: entity.totalInCents,
      createdAt: entity.createdAt,
      syncStatus: entity.syncStatus,
    );
  }

  /// Unique sale identifier.
  final String id;

  /// Sequential invoice or receipt number.
  final String invoiceNumber;

  /// Original table identifier.
  final String? tableId;

  /// Split account identifier.
  final String? tableAccountId;

  /// Daily cash register session identifier.
  final String? cashRegisterSessionId;

  /// Payment method identifier.
  final String paymentMethodId;

  /// Captured payment reference.
  final String? paymentReference;

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

  /// Database value for status.
  String get statusValue => status.name;

  /// Database value for sync status.
  String get syncStatusValue => syncStatus.name;

  /// Creates a modified copy.
  SaleModel copyWith({SaleSyncStatus? syncStatus}) {
    return SaleModel(
      id: id,
      invoiceNumber: invoiceNumber,
      tableId: tableId,
      tableAccountId: tableAccountId,
      cashRegisterSessionId: cashRegisterSessionId,
      paymentMethodId: paymentMethodId,
      paymentReference: paymentReference,
      status: status,
      subtotalInCents: subtotalInCents,
      totalInCents: totalInCents,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Converts this model to a domain entity.
  Sale toEntity() {
    return Sale(
      id: id,
      invoiceNumber: invoiceNumber,
      tableId: tableId,
      tableAccountId: tableAccountId,
      cashRegisterSessionId: cashRegisterSessionId,
      paymentMethodId: paymentMethodId,
      paymentReference: paymentReference,
      status: status,
      subtotalInCents: subtotalInCents,
      totalInCents: totalInCents,
      createdAt: createdAt,
      syncStatus: syncStatus,
    );
  }

  static SaleStatus _statusFromText(String value) {
    return SaleStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SaleStatus.completed,
    );
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
    tableId,
    tableAccountId,
    cashRegisterSessionId,
    paymentMethodId,
    paymentReference,
    status,
    subtotalInCents,
    totalInCents,
    createdAt,
    syncStatus,
  ];
}
