import 'package:equatable/equatable.dart';

/// Auditable record of a voided sale.
final class SaleVoid extends Equatable {
  /// Creates a sale void audit record.
  const SaleVoid({
    required this.id,
    required this.saleId,
    required this.reason,
    required this.voidedBy,
    required this.voidedAt,
  });

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

  @override
  List<Object?> get props => [id, saleId, reason, voidedBy, voidedAt];
}
