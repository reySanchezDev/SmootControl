import 'package:equatable/equatable.dart';

/// Daily cash register state.
enum CashRegisterStatus {
  /// Cash register is open for sales and expenses.
  open,

  /// Cash register was counted and closed.
  closed,
}

/// Daily cash register controlled by a cashier.
final class CashRegisterSession extends Equatable {
  /// Creates a cash register session.
  const CashRegisterSession({
    required this.id,
    required this.cashierId,
    required this.businessDate,
    required this.openingCashInCents,
    required this.status,
    this.physicalClosingCashInCents,
  });

  /// Unique session identifier.
  final String id;

  /// Cashier user identifier.
  final String cashierId;

  /// Business date controlled by this session.
  final DateTime businessDate;

  /// Starting cash given for change.
  final int openingCashInCents;

  /// Physical cash counted when closing.
  final int? physicalClosingCashInCents;

  /// Current cash register state.
  final CashRegisterStatus status;

  @override
  List<Object?> get props => [
    id,
    cashierId,
    businessDate,
    openingCashInCents,
    physicalClosingCashInCents,
    status,
  ];
}
