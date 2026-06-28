import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';

/// Data model for historical sale items.
final class SaleItemModel extends Equatable {
  /// Creates a sale item model.
  const SaleItemModel({
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

  /// Creates a model from a local Drift row.
  factory SaleItemModel.fromLocal(LocalSaleItem row) {
    return SaleItemModel(
      id: row.id,
      saleId: row.saleId ?? '',
      tableId: row.tableId,
      tableAccountId: row.tableAccountId,
      productId: row.productId,
      productName: row.productName,
      categoryName: row.categoryName,
      selectedOptionsLabel: row.selectedOptionsLabel,
      quantity: row.quantity,
      unitPriceInCents: row.unitPriceInCents,
      unitCostInCents: row.unitCostInCents,
      createdAt: row.createdAt,
    );
  }

  /// Creates a model from a domain entity.
  factory SaleItemModel.fromEntity(SaleItem entity) {
    return SaleItemModel(
      id: entity.id,
      saleId: entity.saleId,
      tableId: entity.tableId,
      tableAccountId: entity.tableAccountId,
      productId: entity.productId,
      productName: entity.productName,
      categoryName: entity.categoryName,
      selectedOptionsLabel: entity.selectedOptionsLabel,
      quantity: entity.quantity,
      unitPriceInCents: entity.unitPriceInCents,
      unitCostInCents: entity.unitCostInCents,
      createdAt: entity.createdAt,
    );
  }

  /// Unique item identifier.
  final String id;

  /// Sale identifier.
  final String saleId;

  /// Original table identifier.
  final String? tableId;

  /// Split account identifier.
  final String? tableAccountId;

  /// Product identifier.
  final String productId;

  /// Historical product name.
  final String productName;

  /// Historical category name.
  final String categoryName;

  /// Historical selected options.
  final String? selectedOptionsLabel;

  /// Quantity sold.
  final int quantity;

  /// Historical unit price.
  final int unitPriceInCents;

  /// Historical unit cost.
  final int unitCostInCents;

  /// Local creation date.
  final DateTime createdAt;

  /// Converts this model to a domain entity.
  SaleItem toEntity() {
    return SaleItem(
      id: id,
      saleId: saleId,
      tableId: tableId,
      tableAccountId: tableAccountId,
      productId: productId,
      productName: productName,
      categoryName: categoryName,
      selectedOptionsLabel: selectedOptionsLabel,
      quantity: quantity,
      unitPriceInCents: unitPriceInCents,
      unitCostInCents: unitCostInCents,
      createdAt: createdAt,
    );
  }

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
