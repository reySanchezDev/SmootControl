/// Remote cash register row used by administrative screens.
final class CashRegisterAdminRecord {
  /// Creates a remote cash register row.
  const CashRegisterAdminRecord({
    required this.id,
    required this.cashierId,
    required this.businessDate,
    required this.openingCashInCents,
    required this.status,
    required this.openedAt,
    required this.updatedAt,
    this.physicalClosingCashInCents,
    this.closedAt,
  });

  /// Remote cash register id.
  final String id;

  /// Remote cashier id.
  final String cashierId;

  /// Business date controlled by this cash register.
  final DateTime businessDate;

  /// Opening cash amount in cents.
  final int openingCashInCents;

  /// Physical closing cash amount in cents.
  final int? physicalClosingCashInCents;

  /// Remote status: open or closed.
  final String status;

  /// Remote open timestamp.
  final DateTime openedAt;

  /// Remote close timestamp, when available.
  final DateTime? closedAt;

  /// Remote updated timestamp.
  final DateTime updatedAt;

  /// Returns a copy with edited administrative fields.
  CashRegisterAdminRecord copyWith({
    int? openingCashInCents,
    int? physicalClosingCashInCents,
    String? status,
  }) {
    return CashRegisterAdminRecord(
      id: id,
      cashierId: cashierId,
      businessDate: businessDate,
      openingCashInCents: openingCashInCents ?? this.openingCashInCents,
      physicalClosingCashInCents:
          physicalClosingCashInCents ?? this.physicalClosingCashInCents,
      status: status ?? this.status,
      openedAt: openedAt,
      closedAt: closedAt,
      updatedAt: updatedAt,
    );
  }
}
