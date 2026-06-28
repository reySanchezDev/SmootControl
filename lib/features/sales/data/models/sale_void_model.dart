import 'package:equatable/equatable.dart';
import 'package:smoo_control/core/database/app_database.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_void.dart';

/// Data model for auditable sale voids.
final class SaleVoidModel extends Equatable {
  /// Creates a sale void model.
  const SaleVoidModel({
    required this.id,
    required this.saleId,
    required this.reason,
    required this.voidedBy,
    required this.voidedAt,
  });

  /// Creates a model from a local Drift row.
  factory SaleVoidModel.fromLocal(LocalSaleVoid row) {
    return SaleVoidModel(
      id: row.id,
      saleId: row.saleId,
      reason: row.reason,
      voidedBy: row.voidedBy,
      voidedAt: row.voidedAt,
    );
  }

  /// Unique void identifier.
  final String id;

  /// Sale that was voided.
  final String saleId;

  /// Required void reason.
  final String reason;

  /// User that voided the sale.
  final String voidedBy;

  /// Date and time when the sale was voided.
  final DateTime voidedAt;

  /// Converts this model to a domain entity.
  SaleVoid toEntity() {
    return SaleVoid(
      id: id,
      saleId: saleId,
      reason: reason,
      voidedBy: voidedBy,
      voidedAt: voidedAt,
    );
  }

  @override
  List<Object?> get props => [id, saleId, reason, voidedBy, voidedAt];
}
