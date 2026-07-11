part of 'supabase_report_summary_service.dart';

final class _RemoteSale {
  const _RemoteSale({
    required this.id,
    required this.invoiceNumber,
    required this.paymentMethodId,
    required this.status,
    required this.syncStatus,
    required this.totalInCents,
    required this.createdAt,
    this.tableId,
    this.tableAccountId,
    this.cashRegisterSessionId,
    this.paymentReference,
  });

  final String id;
  final String invoiceNumber;
  final String? tableId;
  final String? tableAccountId;
  final String? cashRegisterSessionId;
  final String paymentMethodId;
  final String? paymentReference;
  final String status;
  final String syncStatus;
  final int totalInCents;
  final DateTime createdAt;
}

final class _RemoteSaleItem {
  const _RemoteSaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.categoryName,
    required this.quantity,
    required this.unitPriceInCents,
    required this.unitCostInCents,
    required this.totalInCents,
    required this.totalCostInCents,
    required this.createdAt,
    this.tableAccountId,
    this.selectedOptionsLabel,
  });

  final String id;
  final String saleId;
  final String? tableAccountId;
  final String productId;
  final String productName;
  final String categoryName;
  final String? selectedOptionsLabel;
  final int quantity;
  final int unitPriceInCents;
  final int unitCostInCents;
  final int totalInCents;
  final int totalCostInCents;
  final DateTime createdAt;
}

final class _RemoteExpense {
  const _RemoteExpense({
    required this.id,
    required this.categoryId,
    required this.amountInCents,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.cashRegisterSessionId,
  });

  final String id;
  final String categoryId;
  final String? cashRegisterSessionId;
  final int amountInCents;
  final String description;
  final String createdBy;
  final DateTime createdAt;
}

final class _RemoteCashSession {
  const _RemoteCashSession({
    required this.id,
    required this.cashierId,
    required this.businessDate,
    required this.openingCashInCents,
    required this.status,
    this.physicalClosingCashInCents,
  });

  final String id;
  final String cashierId;
  final DateTime businessDate;
  final int openingCashInCents;
  final int? physicalClosingCashInCents;
  final String status;
}
