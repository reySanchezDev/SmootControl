import 'package:equatable/equatable.dart';

/// Historical item persisted as part of a completed sale.
final class SaleItem extends Equatable {
  /// Creates a sale item.
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.categoryName,
    required this.quantity,
    required this.unitPriceInCents,
    required this.unitCostInCents,
    required this.createdAt,
    this.selectedOptionsLabel,
    this.tableId,
    this.tableAccountId,
  });

  /// Unique item identifier.
  final String id;

  /// Sale identifier.
  final String saleId;

  /// Original table identifier, when applicable.
  final String? tableId;

  /// Split account identifier, when applicable.
  final String? tableAccountId;

  /// Product identifier.
  final String productId;

  /// Historical product name.
  final String productName;

  /// Historical category name.
  final String categoryName;

  /// Historical selected options copied at sale time.
  final String? selectedOptionsLabel;

  /// Quantity sold.
  final int quantity;

  /// Historical unit price.
  final int unitPriceInCents;

  /// Historical unit cost.
  final int unitCostInCents;

  /// Local creation date.
  final DateTime createdAt;

  /// Line total.
  int get totalInCents => quantity * unitPriceInCents;

  /// Line estimated cost.
  int get totalCostInCents => quantity * unitCostInCents;

  @override
  List<Object?> get props => [
    id,
    saleId,
    tableId,
    tableAccountId,
    productId,
    productName,
    categoryName,
    selectedOptionsLabel,
    quantity,
    unitPriceInCents,
    unitCostInCents,
    createdAt,
  ];
}
